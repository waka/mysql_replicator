# frozen_string_literal: true

require 'digest'

module MysqlReplicator
  module Connections
    class Auth
      def self.perform(connection, user, password, auth_plugin_name, auth_plugin_data)
        unless ['caching_sha2_password', 'mysql_native_password', 'sha256_password'].include?(auth_plugin_name)
          raise MysqlReplicator::Error, "Unsupported authentication plugin: #{auth_plugin_name}"
        end

        authentication_packet = build_authentication_packet(user, password, auth_plugin_name, auth_plugin_data)
        connection.send_packet(authentication_packet)
        puts "Send packet: #{authentication_packet.unpack('H*')[0]}"
        payload = connection.read_packet
        puts "Received payload: #{payload.unpack('H*')[0]}"
        #
        #         # First byte of the response is result type
        #         first_byte = payload[0].ord
        #         case first_byte
        #         when 0x00 # OK
        #           MysqlReplicator::Logger.debug 'Authentication successful'
        #         when 0xFF # ERR
        #           error_code = payload[1..2].unpack('v')[0]
        #           error_message = payload.length > 9 ? payload[9..] : ''
        #           raise MysqlReplicator::Error, "Authentication Error: code is #{error_code}, message is #{error_message}"
        #         when 0x01 # More data
        #           if payload.length > 1 && payload[1].ord == 0x04
        #             raise MysqlReplicator::Error, 'Required full-authentication (password is not cached)'
        #           end
        #
        #           raise MysqlReplicator::Error, 'Unexpected packet of More data'
        #         when 0xFE # Auth Switch
        #           raise MysqlReplicator::Error, 'Required to switch authentication method'
        #         else
        #           raise MysqlReplicator::Error, "Unexpected response: #{first_byte.to_s(16)}"
        #         end
      end

      def self.build_authentication_packet(user, password, auth_plugin_name, auth_plugin_data)
        # Client feature flag
        client_flags = 0x200 |   # CLIENT_PROTOCOL_41
                       0x8000 |  # CLIENT_SECURE_CONNECTION
                       0x80000 | # CLIENT_PLUGIN_AUTH
                       0x8 |     # CLIENT_CONNECT_WITH_DB
                       0x800     # CLIENT_SSL (optional)

        # Max packet size
        # MySQL default max packet size is 4GB, but we use a smaller value
        # to avoid issues with large packets.
        # This value can be adjusted based on your needs.
        max_packet_size = 0x40000000

        # Character set
        # MySQL 8.0 uses utf8mb4_0900_ai_ci as the default character set
        charset = 0xFF # utf8mb4_0900_ai_ci (ID: 255)

        # Reserved (23 bytes)
        reserved = "\0" * 23

        # Username
        username_data = user + "\0"

        # Authentication data for password
        if password.empty?
          auth_response = "\0"
        else
          auth_response = calculate_caching_sha2_auth_response(password, auth_plugin_data)
          auth_response_length = [auth_response.length].pack('C')
          auth_response = auth_response_length + auth_response
        end

        # Database (optional)
        database_data = "\0"

        # Authentication plugin name
        auth_plugin = auth_plugin_name + "\0"

        # Packet payload
        payload = [client_flags].pack('V') +
                  [max_packet_size].pack('V') +
                  [charset].pack('C') +
                  reserved +
                  username_data +
                  auth_response +
                  database_data +
                  auth_plugin

        # Packet header
        packet_length = payload.length
        sequence_id = 1
        header = [packet_length].pack('V')[0..2] + [sequence_id].pack('C')

        header + payload
      end

      # caching_sha2_password authentication response
      # SHA256(password) XOR SHA256(SHA256(SHA256(password)) + auth_plugin_data)
      def self.calculate_caching_sha2_auth_response(password, auth_plugin_data)
        password_sha256 = Digest::SHA256.digest(password)
        password_sha256_sha256 = Digest::SHA256.digest(password_sha256)

        scramble_input = password_sha256_sha256 + auth_plugin_data
        scramble_sha256 = Digest::SHA256.digest(scramble_input)

        # XOR
        auth_response = ''
        password_sha256.bytes.each_with_index do |byte, i|
          auth_response += (byte ^ scramble_sha256.bytes[i]).chr
        end

        auth_response
      end
    end
  end
end
