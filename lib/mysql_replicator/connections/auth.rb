# frozen_string_literal: true
# rbs_inline: enabled

require 'digest'
require 'openssl'

module MysqlReplicator
  module Connections
    class Auth
      CLIENT_PLUGIN_AUTH = 0x00080000 #: Integer
      CLIENT_SECURE_CONNECTION = 0x00008000 #: Integer
      CLIENT_PROTOCOL_41 = 0x00000200 #: Integer
      CLIENT_CONNECT_WITH_DB = 0x00000008 #: Integer
      CLIENT_MULTI_STATEMENTS = 0x00010000 #: Integer
      CLIENT_MULTI_RESULTS = 0x00020000 #: Integer

      # @rbs connection: MysqlReplicator::Connection
      # @rbs user: String
      # @rbs password: String
      # @rbs database: String
      # @rbs handshake_info: MysqlReplicator::Connections::Handshake::handshake
      # @rbs return: void
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

      # @rbs connection: MysqlReplicator::Connection
      # @rbs user: String
      # @rbs password: String
      # @rbs database: String
      # @rbs handshake_info: MysqlReplicator::Connections::Handshake::handshake
      # @rbs return: void
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
        if MysqlReplicator::StringUtil.read_uint8(public_key_response_packet[:payload][0]) != 0x01
          raise MysqlReplicator::Error, 'Failed to retrieve public key'
        end

        # Auth with RSA encryption
        public_key = public_key_response_packet[:payload][1..] || ''
        encrypted_password_payload = build_rsa_encrypt_password_payload(password, public_key, handshake_info[:auth_plugin_data])
        connection.send_packet(encrypted_password_payload)

        final_auth_response_packet = connection.read_packet
        return unless MysqlReplicator::StringUtil.read_uint8(final_auth_response_packet[:payload][0]) != 0x00

        raise MysqlReplicator::Error, 'RSA encryption authentication failed'
      end

      # @rbs packet: MysqlReplicator::Connection::packet
      # @rbs return: :success | :challenge
      def self.handle_caching_sha2_password_response(packet)
        payload = packet[:payload]

        # First byte of the response is result type
        first_byte = MysqlReplicator::StringUtil.read_uint8(payload[0])
        case first_byte
        when 0x00
          :success
        when 0x01
          more_data = payload[1..] || ['']
          command = MysqlReplicator::StringUtil.read_uint8(more_data[0])
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
            "code = #{(payload[1..2] || '').unpack('v')[0]}, " \
            "sql_state_marker = #{(payload[3] || '').chr}, " \
            "sql_state = #{payload[4..8]}, " \
            "message = #{payload[9..]}"
        end
      end

      # @rbs user: String
      # @rbs password: String
      # @rbs database: String
      # @rbs handshake_info: MysqlReplicator::Connections::Handshake::handshake
      # @rbs return: String
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
        auth_plugin_name_data = handshake_info[:auth_plugin_name].to_s + "\x00"

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
      #
      # @rbs password: String
      # @rbs salt: String
      # @rbs return: String
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
          payload += (byte ^ hash3[i].to_s.ord).chr
        end
        payload
      end

      # @rbs password: String
      # @rbs public_key: String
      # @rbs scramble: String
      # @rbs return: String
      def self.build_rsa_encrypt_password_payload(password, public_key, scramble)
        rsa_public_key = OpenSSL::PKey::RSA.new(public_key)

        # Password is null-terminated string
        password_with_null = password + "\x00"

        password_bytes = password_with_null.encode(Encoding::UTF_8).bytes
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

      # @rbs payload: String
      # @rbs with_database: bool
      # @rbs return: void
      def self.debug_caching_sha2_password_payload(payload, with_database)
        offset = 0

        client_flags = MysqlReplicator::StringUtil.read_uint32(payload[offset..(offset + 3)])
        offset += 4

        max_packet_size = MysqlReplicator::StringUtil.read_uint32(payload[offset..(offset + 3)])
        offset += 4

        character_set = MysqlReplicator::StringUtil.read_uint8(payload[offset])
        offset += 1

        reserved = MysqlReplicator::StringUtil.read_str(payload[offset..(offset + 22)])
        offset += 23

        null_pos = payload.index("\x00", offset).to_i
        user = MysqlReplicator::StringUtil.read_str(payload[offset...null_pos])
        offset = null_pos + 1

        challenge_hash_length = MysqlReplicator::StringUtil.read_uint8(payload[offset])
        offset += 1
        if challenge_hash_length > 0
          challenge_hash_data = MysqlReplicator::StringUtil.read_str(payload[offset..(offset + challenge_hash_length - 1)])
          offset += challenge_hash_length
        end

        if with_database
          db_null_pos = payload.index("\x00", offset).to_i
          database = MysqlReplicator::StringUtil.read_str(payload[offset...db_null_pos])
          offset = db_null_pos + 1
        end

        plugin_null_pos = payload.index("\x00", offset).to_i
        plugin_name = MysqlReplicator::StringUtil.read_str(payload[offset...plugin_null_pos]) if plugin_null_pos

        MysqlReplicator::Logger.debug \
          "===== Start Auth Payload =====\n" \
          "Client flags: #{client_flags.to_i.to_s(16)}\n" \
          "Max packet size: #{max_packet_size}\n" \
          "Character set: #{character_set}\n" \
          "Reserved: #{MysqlReplicator::StringUtil.read_array_from_int8(reserved).all?(&:zero?) ? 'All zero' : 'None zero'}\n" \
          "User: #{user}\n" \
          "Challenge hash length: #{challenge_hash_length}\n" \
          "Challenge hash data: #{MysqlReplicator::StringUtil.read_array_from_int8(challenge_hash_data).map { |b| format('%02X', b) }.join(' ')}\n" \
          "Database name: #{database}\n" \
          "Auth plugin name: #{plugin_name}\n" \
          '===== End Auth Payload ====='
      end

      # @rbs connection: MysqlReplicator::Connection
      # @rbs password: String
      # @rbs handshake_info: MysqlReplicator::Connections::Handshake::handshake
      # @return: void
      def self.mysql_native_password_auth(connection, password, handshake_info)
        auth_payload = build_mysql_native_password_payload(password, handshake_info[:auth_plugin_data])
        connection.send_packet(auth_payload)

        auth_response_packet = connection.read_packet

        return unless MysqlReplicator::StringUtil.read_uint8(auth_response_packet[:payload][0]) != 0x00

        raise MysqlReplicator::Error,
          'mysql_native_password authentication failed: ' \
          "Payload = #{MysqlReplicator::StringUtil.read_array_from_int8(auth_response_packet[:payload]).map { |b| format('%02X', b) }.join(' ')}"
      end

      # @rbs password: String
      # @rbs salt: String
      # @rbs return: String
      def self.build_mysql_native_password_payload(password, salt)
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
          payload += (byte ^ (hash3[i] || '').ord).chr
        end

        payload
      end
    end
  end
end
