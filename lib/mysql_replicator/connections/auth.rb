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

      def self.perform(connection, user, password, database, handshake_info)
        # Auth with caching_sha2_password
        auth_result = perform_auth(connection, user, password, database, handshake_info)
        if auth_result == :success
          MysqlReplicator::Logger.debug 'caching_sha2_password authentication successful!'
          return
        end

        MysqlReplicator::Logger.debug 'trying caching_sha2_password with RSA encryption authentication'

        # Auth with RSA encryption
        rsa_encryption_auth_result = perform_rsa_encryption_auth(connection, password, handshake_info)
        if rsa_encryption_auth_result == :success
          MysqlReplicator::Logger.debug 'caching_sha2_password with RSA encryption authentication successful!'
          return
        end

        raise MysqlReplicator::Error, 'Failed to authenticate caching_sha2_password with RSA encryption'
      end

      def self.perform_auth(connection, user, password, database, handshake_info)
        auth_payload = build_auth_payload(user, password, database, handshake_info)
        connection.send_packet(auth_payload)

        auth_response_packet = connection.read_packet
        payload = auth_response_packet[:payload]

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
          error_code = payload[1..2].unpack('v')[0]
          sql_state_marker = payload[3].chr
          sql_state = payload[4..8]
          error_message = payload[9..]
          raise MysqlReplicator::Error,
            'Authentication Error: ' \
            "first_byte: #{first_byte} code is #{error_code}, " \
            "sql_state_marker is #{sql_state_marker}, " \
            "sql_state is #{sql_state}, " \
            "message is #{error_message}"
        end
      end

      def self.perform_rsa_encryption_auth(connection, password, handshake_info)
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
        if final_auth_response_packet[:payload][0].unpack('C')[0] == 0x00
          :success
        else
          :error
        end
      end

      def self.build_auth_payload(user, password, database, handshake_info)
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
        auth_response = build_caching_sha2_password_payload(password, handshake_info[:auth_plugin_data])

        # Database (optional)
        database_data = database && !database.empty? ? database + "\x00" : ''

        # Authentication plugin name
        auth_plugin_name_data = handshake_info[:auth_plugin_name] + "\x00"

        # Payload of packet
        payload = [client_flags].pack('V') +
                  [max_packet_size].pack('V') +
                  [charset].pack('C') +
                  reserved_data +
                  username_data +
                  [auth_response.length].pack('C') + auth_response +
                  database_data +
                  auth_plugin_name_data
        debug_auth_payload(payload, !database_data.empty?)

        payload
      end

      # caching_sha2_password authentication payload
      # SHA256(password) XOR SHA256(SHA256(SHA256(password)) + salt)
      def self.build_caching_sha2_password_payload(password, salt)
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

      def self.build_rsa_encrypt_password_payload(password, public_key, salt)
        rsa_public_key = OpenSSL::PKey::RSA.new(public_key)

        # Password is null-terminated string
        password_with_null = password + "\x00"
        password_bytes = password_with_null.encode('UTF-8').bytes

        scramble = case salt
                   when String
                     salt.bytes
                   when Array
                     salt
                   else
                     raise "Invalid salt type: #{salt.class}"
                   end

        xor_result = []
        password_bytes.each_with_index do |byte, index|
          scramble_byte = scramble[index % scramble.length]
          xor_result << (byte ^ scramble_byte)
        end
        data_to_encrypt = xor_result.pack('C*')

        begin
          # First, try OAEP padding (MySQL 8.0.5+)
          encrypted_data = rsa_public_key.public_encrypt(data_to_encrypt, OpenSSL::PKey::RSA::PKCS1_OAEP_PADDING)
        rescue OpenSSL::PKey::RSAError
          # If OAEP fails, use PKCS#1 (MySQL 8.0.4 and earlier)
          encrypted_data = rsa_public_key.public_encrypt(data_to_encrypt, OpenSSL::PKey::RSA::PKCS1_PADDING)
        end
        encrypted_data
      end

      def self.debug_auth_payload(payload, with_database)
        MysqlReplicator::Logger.debug '===== Start Auth Payload ====='

        offset = 0

        MysqlReplicator::Logger.debug "Client flags: #{payload[offset..(offset + 3)].unpack('V')[0].to_s(16)}"
        offset += 4

        MysqlReplicator::Logger.debug "Max packet size: #{payload[offset..(offset + 3)].unpack('V')[0]}"
        offset += 4

        MysqlReplicator::Logger.debug "Character set: #{payload[offset].unpack('C')[0]}"
        offset += 1

        MysqlReplicator::Logger.debug "Reserved: #{payload[offset..(offset + 22)].unpack('C*').all?(&:zero?) ? 'All zero' : 'None zero'}"
        offset += 23

        null_pos = payload.index("\x00", offset)
        user_in_packet = payload[offset...null_pos]
        MysqlReplicator::Logger.debug "User: '#{user_in_packet}'"
        offset = null_pos + 1

        auth_response_length = payload[offset].unpack('C')[0]
        MysqlReplicator::Logger.debug "Auth reponse length: #{auth_response_length}"
        offset += 1

        if auth_response_length > 0
          auth_response_data = payload[offset..(offset + auth_response_length - 1)]
          MysqlReplicator::Logger.debug "Auth response data: #{auth_response_data.unpack('C*').map { |b| format('%02X', b) }.join(' ')}"
          offset += auth_response_length
        end

        if with_database
          db_null_pos = payload.index("\x00", offset)
          db_name = payload[offset...db_null_pos]
          MysqlReplicator::Logger.debug "Database name: '#{db_name}'"
          offset = db_null_pos + 1
        end

        plugin_null_pos = payload.index("\x00", offset)
        plugin_name = payload[offset...plugin_null_pos] if plugin_null_pos
        MysqlReplicator::Logger.debug "Auth plugin name: '#{plugin_name}'"

        MysqlReplicator::Logger.debug '===== End Auth Payload ====='
      end
    end
  end
end
