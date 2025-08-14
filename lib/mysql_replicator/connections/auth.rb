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

      def self.perform(connection, user, password, database, auth_plugin_name, auth_plugin_data)
        unless ['caching_sha2_password', 'mysql_native_password', 'sha256_password'].include?(auth_plugin_name)
          raise MysqlReplicator::Error, "Unsupported authentication plugin: #{auth_plugin_name}"
        end

        # Auth
        auth_payload = build_auth_payload(
          user,
          password,
          database,
          auth_plugin_name,
          auth_plugin_data
        )
        connection.send_packet(auth_payload)

        auth_response_packet = connection.read_packet
        auth_result = handle_auth_response_packet(auth_response_packet)
        if auth_result == :success
          MysqlReplicator::Logger.debug "Authentication successful for user '#{user}'"
          return
        end

        # Challenge auth
        auth_challenge_payload = compute_caching_sha2_password(password, auth_plugin_data)
        connection.send_packet(auth_challenge_payload)

        auth_challenge_response_packet = connection.read_packet
        auth_challenge_result = handle_auth_challenge_response_packet(auth_challenge_response_packet)
        if auth_challenge_result == :success
          MysqlReplicator::Logger.debug "Authentication successful for user '#{user}'"
          return
        end

        # Request public key for RSA encryption
        public_key_payload = [0x02].pack('C')
        connection.send_packet(public_key_payload)

        public_key_response_packet = connection.read_packet
        if public_key_response_packet[:payload][0].unpack('C')[0] != 0x01
          raise MysqlReplicator::Error, 'Failed to retrieve public key'
        end

        # Auth with RSA encryption
        public_key = public_key_response_packet[:payload][1..]
        encrypted_password_payload = rsa_encrypt_password(password, public_key)
        connection.send_packet(encrypted_password_payload)

        final_auth_response_packet = connection.read_packet
        if final_auth_response_packet[:payload][0].unpack('C')[0] != 0x00
          raise MysqlReplicator::Error, 'Failed to authenticate RSA encryption'
        end

        # Success!!
        MysqlReplicator::Logger.debug "Authentication successful for user '#{user}'"
      end

      def self.build_auth_payload(user, password, database, auth_plugin_name, auth_plugin_data)
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
        charset = 255 # utf8mb4_0900_ai_ci (ID: 255)

        # Reserved (23 bytes)
        reserved = "\x00" * 23

        # Username
        username_data = user + "\x00"

        # If caching_sha2_password, send empty auth response at first
        auth_response = if auth_plugin_name == 'caching_sha2_password'
                          [0].pack('C') # auth response length is 0
                        else
                          # Other authentication methods (simplify)
                          auth_response = compute_mysql_native_password(password, auth_plugin_data)
                          [auth_response.length].pack('C') + auth_response
                        end

        # Database (optional)
        database_data = database && !database.empty? ? database + "\x00" : ''

        # Authentication plugin name
        auth_plugin = auth_plugin_name + "\x00"

        # Payload of packet
        payload = [client_flags].pack('V') +
                  [max_packet_size].pack('V') +
                  [charset].pack('C') +
                  reserved +
                  username_data +
                  auth_response +
                  database_data +
                  auth_plugin

        MysqlReplicator::Logger.debug '===== Auth Payload ====='

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
        if database
          db_null_pos = payload.index("\x00", offset)
          db_name = payload[offset...db_null_pos]
          MysqlReplicator::Logger.debug "Database name: '#{db_name}'"
          offset = db_null_pos + 1
        end
        plugin_null_pos = payload.index("\x00", offset)
        plugin_name = payload[offset...plugin_null_pos] if plugin_null_pos
        MysqlReplicator::Logger.debug "Auth plugin name: '#{plugin_name}'"

        payload
      end

      def self.handle_auth_response_packet(packet)
        payload = packet[:payload]

        # First byte of the response is result type
        first_byte = payload[0].unpack('C')[0]
        if first_byte == 0x00
          :success
        elsif first_byte == 0x01
          :challenge
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

      def self.handle_auth_challenge_response_packet(packet)
        payload = packet[:payload]

        # First byte of the response is result type
        first_byte = payload[0].unpack('C')[0]
        if first_byte == 0x00
          :success
        elsif first_byte == 0x01
          # Fast auth failed, need to send clear text password or use RSA encryption
          auth_continue = payload[1].unpack('C')[0]
          case auth_continue
          when 0x03
            # Fast auth succeeded
            :success
          when 0x04
            # Fast auth failed
            :challenge
          else
            raise MysqlReplicator::Error, "Unexpected auth continue code: #{auth_continue}"
          end
        else
          error_code = payload[1..2].unpack('v')[0]
          error_message = payload[3..]
          raise MysqlReplicator::Error, "Authentication Error: code is #{error_code}, message is #{error_message}"
        end
      end

      # caching_sha2_password authentication payload
      # SHA256(password) XOR SHA256(SHA256(SHA256(password)) + salt)
      def self.compute_caching_sha2_password(password, salt)
        return '' if password.empty?

        # SHA256(password)
        hash1 = Digest::SHA256.digest(password)
        # SHA256(SHA256(password))
        hash2 = Digest::SHA256.digest(hash1)
        # SHA256(SHA256(SHA256(password)), salt)
        hash3 = Digest::SHA256.digest(hash2 + salt)

        # XOR hash1 and hash3
        result = ''
        hash1.each_byte.with_index do |byte, i|
          result += (byte ^ hash3[i].ord).chr
        end
        result
      end

      # mysql_native_password authentication payload
      # SHA1(password) XOR SHA1(SHA1(SHA1(password)) + salt)
      def self.compute_mysql_native_password(password, salt)
        return '' if password.empty?

        # SHA1(password)
        hash1 = Digest::SHA1.digest(password)
        # SHA1(SHA1(password))
        hash2 = Digest::SHA1.digest(hash1)
        # SHA1(salt + SHA1(SHA1(password)))
        hash3 = Digest::SHA1.digest(salt + hash2)

        # XOR hash1 and hash3
        result = ''
        hash1.each_byte.with_index do |byte, i|
          result += (byte ^ hash3[i].ord).chr
        end
        result
      end

      def self.rsa_encrypt_password(password, public_key)
        # Password is null-terminated string
        password_with_null = password + "\x00"

        rsa_key = OpenSSL::PKey::RSA.new(public_key)
        rsa_key.public_encrypt(password_with_null, OpenSSL::PKey::RSA::PKCS1_PADDING)
      end
    end
  end
end
