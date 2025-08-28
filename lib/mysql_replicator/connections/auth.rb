# frozen_string_literal: true

require 'digest'
require 'openssl'

module MysqlReplicator
  module Connections
    class Auth
      CLIENT_PLUGIN_AUTH = 0x00080000
      CLIENT_SECURE_CONNECTION = 0x00008000
      CLIENT_PROTOCOL_41 = 0x00000200
      CLIENT_CONNECT_WITH_DB = 0x00000008
      CLIENT_MULTI_STATEMENTS = 0x00010000
      CLIENT_MULTI_RESULTS = 0x00020000

      def self.execute(connection, user, password, database, handshake_info)
        auth_plugin_name = handshake_info[:auth_plugin_name]

        case auth_plugin_name
        when 'caching_sha2_password'
          caching_sha2_password_auth(connection, user, password, database, handshake_info)
          MysqlReplicator::Logger.debug 'Authentication by caching_sha2_password is successful!'
        when 'mysql_native_password'
          mysql_native_password_auth(connection, password, handshake_info)
          MysqlReplicator::Logger.debug 'Authentication by mysql_native_password is successful!'
        else
          raise MysqlReplicator::Error, "Unsupported auth plugin name: #{auth_plugin_name}"
        end

        # Clear EOF packet (at finish)
        connection.flush_socket_buffer
      end

      def self.caching_sha2_password_auth(connection, user, password, database, handshake_info)
        auth_payload = build_caching_sha2_password_payload(user, password, database, handshake_info)
        debug_caching_sha2_password_payload(auth_payload, !database.empty?)
        connection.send_packet(auth_payload)

        auth_response_packet = connection.read_packet
        if handle_caching_sha2_password_response(auth_response_packet) == :success
          return
        end

        MysqlReplicator::Logger.debug 'Trying RSA encryption authentication...'

        # Request public key for RSA encryption
        public_key_payload = [0x02].pack('C')
        connection.send_packet(public_key_payload)

        public_key_response_packet = connection.read_packet
        if public_key_response_packet[:payload][0].unpack('C')[0] != 0x01
          raise MysqlReplicator::Error, 'Failed to retrieve public key'
        end

        # Auth with RSA encryption
        public_key = public_key_response_packet[:payload][1..]
        encrypted_password_payload = build_rsa_encrypt_password_payload(password, public_key, handshake_info[:auth_plugin_data])
        connection.send_packet(encrypted_password_payload)

        final_auth_response_packet = connection.read_packet
        return unless final_auth_response_packet[:payload][0].unpack('C')[0] != 0x00

        raise MysqlReplicator::Error, 'RSA encryption authentication failed'
      end

      def self.handle_caching_sha2_password_response(packet)
        payload = packet[:payload]

        # First byte of the response is result type
        first_byte = payload[0].unpack('C')[0]
        case first_byte
        when 0x00
          :success
        when 0x01
          more_data = payload[1..]
          command = more_data[0].unpack('C')[0]
          case command
          when 0x03
            :success
          when 0x04
            :challenge
          else
            raise MysqlReplicator::Error, "Unexpected command: #{format('%02X', command)}"
          end
        else
          raise MysqlReplicator::Error,
            'Authentication Error: ' \
            "first_byte = #{first_byte}, " \
            "code = #{payload[1..2].unpack('v')[0]}, " \
            "sql_state_marker = #{payload[3].chr}, " \
            "sql_state = #{payload[4..8]}, " \
            "message = #{payload[9..]}"
        end
      end

      def self.build_caching_sha2_password_payload(user, password, database, handshake_info)
        # Client feature flag
        client_flags = CLIENT_PROTOCOL_41 |
                       CLIENT_SECURE_CONNECTION |
                       CLIENT_PLUGIN_AUTH |
                       CLIENT_MULTI_STATEMENTS |
                       CLIENT_MULTI_RESULTS
        client_flags |= CLIENT_CONNECT_WITH_DB if database && !database.empty?

        # Max packet size (4 bytes)
        max_packet_size = 0x01000000

        # Character set
        # MySQL 8.0 uses utf8mb4_0900_ai_ci as the default character set
        charset = handshake_info[:charset]

        # Reserved (23 bytes)
        reserved_data = "\x00" * 23

        # Username
        username_data = user + "\x00"

        # Hash for caching_sha2_password
        challenge_hash = build_caching_sha2_password_hash(password, handshake_info[:auth_plugin_data])

        # Database (optional)
        database_data = database && !database.empty? ? database + "\x00" : ''

        # Authentication plugin name
        auth_plugin_name_data = handshake_info[:auth_plugin_name] + "\x00"

        # Payload of packet
        [client_flags].pack('V') +
          [max_packet_size].pack('V') +
          [charset].pack('C') +
          reserved_data +
          username_data +
          [challenge_hash.length].pack('C') + challenge_hash +
          database_data +
          auth_plugin_name_data
      end

      # Hash value for caching_sha2_password
      # SHA256(password) XOR SHA256(SHA256(SHA256(password)) + salt)
      def self.build_caching_sha2_password_hash(password, salt)
        return '' if password.empty?

        # SHA256(password)
        hash1 = Digest::SHA256.digest(password.encode('utf-8'))
        # SHA256(SHA256(password))
        hash2 = Digest::SHA256.digest(hash1)
        # SHA256(SHA256(SHA256(password)), salt)
        hash3 = Digest::SHA256.digest(hash2 + salt)

        # XOR hash1 and hash3
        payload = ''
        hash1.each_byte.with_index do |byte, i|
          payload += (byte ^ hash3[i].ord).chr
        end
        payload
      end

      def self.build_rsa_encrypt_password_payload(password, public_key, scramble)
        rsa_public_key = OpenSSL::PKey::RSA.new(public_key)

        # Password is null-terminated string
        password_with_null = password + "\x00"

        password_bytes = password_with_null.encode('UTF-8').bytes
        scramble_bytes = scramble.bytes

        xor_result = []
        password_bytes.each_with_index do |byte, index|
          scramble_byte = scramble_bytes[index % scramble_bytes.length]
          xor_result << (byte ^ scramble_byte)
        end
        data_to_encrypt = xor_result.pack('C*')

        begin
          # First, try OAEP padding (MySQL 8.0.5+)
          rsa_public_key.public_encrypt(data_to_encrypt, OpenSSL::PKey::RSA::PKCS1_OAEP_PADDING)
        rescue OpenSSL::PKey::RSAError
          # If OAEP fails, use PKCS#1 (MySQL 8.0.4 and earlier)
          rsa_public_key.public_encrypt(data_to_encrypt, OpenSSL::PKey::RSA::PKCS1_PADDING)
        end
      end

      def self.debug_caching_sha2_password_payload(payload, with_database)
        offset = 0

        client_flags = payload[offset..(offset + 3)].unpack('V')[0]
        offset += 4

        max_packet_size = payload[offset..(offset + 3)].unpack('V')[0]
        offset += 4

        character_set = payload[offset].unpack('C')[0]
        offset += 1

        reserved = payload[offset..(offset + 22)]
        offset += 23

        null_pos = payload.index("\x00", offset)
        user = payload[offset...null_pos]
        offset = null_pos + 1

        challenge_hash_length = payload[offset].unpack('C')[0]
        offset += 1
        if challenge_hash_length > 0
          challenge_hash_data = payload[offset..(offset + challenge_hash_length - 1)]
          offset += challenge_hash_length
        end

        if with_database
          db_null_pos = payload.index("\x00", offset)
          database = payload[offset...db_null_pos]
          offset = db_null_pos + 1
        end

        plugin_null_pos = payload.index("\x00", offset)
        plugin_name = payload[offset...plugin_null_pos] if plugin_null_pos

        MysqlReplicator::Logger.debug \
          "===== Start Auth Payload =====\n" \
          "Client flags: #{client_flags.to_s(16)}\n" \
          "Max packet size: #{max_packet_size}\n" \
          "Character set: #{character_set}\n" \
          "Reserved: #{reserved.unpack('C*').all?(&:zero?) ? 'All zero' : 'None zero'}\n" \
          "User: #{user}\n" \
          "Challenge hash length: #{challenge_hash_length}\n" \
          "Challenge hash data: #{challenge_hash_data.unpack('C*').map { |b| format('%02X', b) }.join(' ')}\n" \
          "Database name: #{database}\n" \
          "Auth plugin name: #{plugin_name}\n" \
          '===== End Auth Payload ====='
      end

      def self.mysql_native_password_auth(connection, password, handshake_info)
        auth_payload = build_mysql_native_password_payload(password, handshake_info[:auth_plugin_data])
        connection.send_packet(auth_payload)

        auth_response_packet = connection.read_packet

        return unless auth_response_packet[:payload][0].unpack('C')[0] != 0x00

        raise MysqlReplicator::Error,
          'mysql_native_password authentication failed: ' \
          "Payload = #{auth_response_packet[:payload].unpack('C*').map { |b| format('%02X', b) }.join(' ')}"
      end

      def build_mysql_native_password_payload(password, salt)
        return '' if password.empty?

        # SHA1(password)
        hash1 = Digest::SHA1.digest(password.encode('utf-8'))
        # SHA1(SHA1(password))
        hash2 = Digest::SHA1.digest(hash1)
        # SHA1(salt + SHA1(SHA1(password)))
        hash3 = Digest::SHA1.digest(salt + hash2)

        # XOR hash1 and hash3
        payload = ''
        hash1.each_byte.with_index do |byte, i|
          payload += (byte ^ hash3[i].ord).chr
        end

        payload
      end
    end
  end
end
