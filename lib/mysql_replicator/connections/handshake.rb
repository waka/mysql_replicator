# frozen_string_literal: true

module MysqlReplicator
  module Connections
    class Handshake
      def self.perform(connection)
        handshake_response_packet = connection.read_packet
        handshake_info = parse_handshake_response_packet(handshake_response_packet)
        debug_handshake_info(handshake_info)
        handshake_info
      end

      def self.parse_handshake_response_packet(packet)
        payload = packet[:payload]
        offset = 0

        # Protocol version (1 byte)
        protocol_version = payload[offset].unpack('C')[0]
        offset += 1

        # Server version is null-terminated string
        server_version_end = payload.index("\0", offset)
        server_version = payload[offset...server_version_end]
        offset = server_version_end + 1

        # ConnectionID is 4bytes and little endian
        connection_id = payload[offset..(offset + 3)].unpack('V')[0]
        offset += 4

        # Authentication plugin data (first 8 bytes)
        auth_plugin_data_part1 = payload[offset..(offset + 7)]
        offset += 8

        # Reserved (1 byte, always 0x00)
        offset += 1

        # Server capability flags (lower 2 bytes)
        capability_flags_lower = payload[offset..(offset + 1)].unpack('v')[0]
        offset += 2

        # After MySQL 8.0, additional authentication plugin information is included
        if offset < payload.length
          # Character set (1 byte)
          charset = payload[offset].unpack('C')[0]
          offset += 1

          # Status flags (2 bytes)
          status_flags = payload[offset..(offset + 1)].unpack('v')[0]
          offset += 2

          # Server capability flags (upper 2 bytes)
          capability_flags_upper = payload[offset..(offset + 1)].unpack('v')[0]
          offset += 2

          # Feature flags
          capability_flags = capability_flags_lower | (capability_flags_upper << 16)

          # Authentication plugin data length (1 byte)
          auth_plugin_data_len = payload[offset].unpack('C')[0]
          offset += 1

          # Reserved (10 bytes)
          offset += 10

          # Authentication plugin data (part 2)
          remaining_auth_data_len = [auth_plugin_data_len - 8, 13].max
          auth_plugin_data_part2 = payload[offset..(offset + remaining_auth_data_len - 1)]
          offset += remaining_auth_data_len

          # Authentication plugin name (null-terminated string)
          plugin_name_end = payload.index("\0", offset)
          auth_plugin_name = payload[offset...plugin_name_end]
          auth_plugin_data = auth_plugin_data_part1 + auth_plugin_data_part2[0..11]
          # Adjust 20 bytes
          if auth_plugin_data.length > 20
            auth_plugin_data = auth_plugin_data[0..19]
          elsif auth_plugin_data.length < 20
            auth_plugin_data += "\x00" * (20 - auth_plugin_data.length)
          end
        else
          auth_plugin_name = 'mysql_native_password'
          auth_plugin_data = auth_plugin_data_part1
        end

        {
          protocol_version: protocol_version,
          server_version: server_version,
          connection_id: connection_id,
          capability_flags: capability_flags,
          charset: charset,
          status_flags: status_flags,
          auth_plugin_name: auth_plugin_name,
          auth_plugin_data: auth_plugin_data
        }
      end

      def self.debug_handshake_info(handshake_info)
        MysqlReplicator::Logger.debug '===== Start Handshake Info ====='
        MysqlReplicator::Logger.debug "Protocol version: #{handshake_info[:protocol_version]}"
        MysqlReplicator::Logger.debug "Server version: #{handshake_info[:server_version]}"
        MysqlReplicator::Logger.debug "Connection ID: #{handshake_info[:connection_id]}"
        MysqlReplicator::Logger.debug "Capability flags: 0x#{handshake_info[:capability_flags].to_s(16).upcase}"
        MysqlReplicator::Logger.debug "Character set: #{handshake_info[:charset]}"
        MysqlReplicator::Logger.debug "Status flags: #{handshake_info[:status_flags]}"
        MysqlReplicator::Logger.debug "Authentication plugin name: #{handshake_info[:auth_plugin_name]}"
        MysqlReplicator::Logger.debug "Authentication plugin data: #{handshake_info[:auth_plugin_data].unpack('C*').map { |b| format('%02X', b) }.join(' ')}}"
        MysqlReplicator::Logger.debug '===== End Handshake Info ====='
      end
    end
  end
end
