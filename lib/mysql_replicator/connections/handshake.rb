# frozen_string_literal: true

module MysqlReplicator
  module Connections
    class Handshake
      def self.perform(connection)
        payload = connection.read_packet
        parse_payload(payload)
      end

      def self.parse_payload(payload)
        offset = 0

        protocol_version = payload[offset].unpack('C')[0]
        offset += 1
        MysqlReplicator::Logger.debug "Protocol version: #{protocol_version}"

        # Server version is null-terminated string
        server_version_end = payload.index("\0", offset)
        server_version = payload[offset...server_version_end]
        offset = server_version_end + 1
        MysqlReplicator::Logger.debug "Server version: #{server_version}"

        # ConnectionID is 4bytes and little endian
        connection_id = payload[offset..(offset + 3)].unpack('V')[0]
        offset += 4
        MysqlReplicator::Logger.debug "Connection ID: #{connection_id}"

        # Authentication plugin data (first 8 bytes)
        auth_plugin_data_part1 = payload[offset..(offset + 7)]
        offset += 8
        MysqlReplicator::Logger.debug "Authentication data (first 8 bytes): #{auth_plugin_data_part1.unpack('H*')[0]}"

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
          MysqlReplicator::Logger.debug "Character set: #{charset}"

          # Status flags (2 bytes)
          status_flags = payload[offset..(offset + 1)].unpack('v')[0]
          offset += 2
          MysqlReplicator::Logger.debug "Status flags: #{status_flags}"

          # Server capability flags (upper 2 bytes)
          capability_flags_upper = payload[offset..(offset + 1)].unpack('v')[0]
          offset += 2

          # Feature flags
          capability_flags = capability_flags_lower | (capability_flags_upper << 16)
          MysqlReplicator::Logger.debug "Feature flags: 0x#{capability_flags.to_s(16).upcase}"
          # Main feature flags
          MysqlReplicator::Logger.debug "  - CLIENT_LONG_PASSWORD: #{(capability_flags & 0x1) != 0}"
          MysqlReplicator::Logger.debug "  - CLIENT_FOUND_ROWS: #{(capability_flags & 0x2) != 0}"
          MysqlReplicator::Logger.debug "  - CLIENT_LONG_FLAG: #{(capability_flags & 0x4) != 0}"
          MysqlReplicator::Logger.debug "  - CLIENT_CONNECT_WITH_DB: #{(capability_flags & 0x8) != 0}"
          MysqlReplicator::Logger.debug "  - CLIENT_PROTOCOL_41: #{(capability_flags & 0x200) != 0}"
          MysqlReplicator::Logger.debug "  - CLIENT_SSL: #{(capability_flags & 0x800) != 0}"
          MysqlReplicator::Logger.debug "  - CLIENT_SECURE_CONNECTION: #{(capability_flags & 0x8000) != 0}"
          MysqlReplicator::Logger.debug "  - CLIENT_PLUGIN_AUTH: #{(capability_flags & 0x80000) != 0}"

          # Authentication plugin data length (1 byte)
          auth_plugin_data_len = payload[offset].unpack('C')[0]
          MysqlReplicator::Logger.debug "Authentication plugin data length: #{auth_plugin_data_len}"
          offset += 1

          # Reserved (10 bytes)
          offset += 10

          # Authentication plugin data (part 2)
          remaining_auth_data_len = [auth_plugin_data_len - 8, 13].max
          auth_plugin_data_part2 = payload[offset..(offset + remaining_auth_data_len - 1)]
          offset += remaining_auth_data_len
          MysqlReplicator::Logger.debug "Authentication data (part 2, #{remaining_auth_data_len} bytes): #{auth_plugin_data_part2.unpack('H*')[0]}"

          # Authentication plugin name (null-terminated string)
          plugin_name_end = payload.index("\0", offset)
          auth_plugin_name = payload[offset...plugin_name_end]
          MysqlReplicator::Logger.debug "Authentication plugin name: #{auth_plugin_name}"

          auth_plugin_data = auth_plugin_data_part1 + auth_plugin_data_part2[0..11]
        else
          auth_plugin_name = 'mysql_native_password'
          MysqlReplicator::Logger.debug "Authentication plugin name: #{auth_plugin_name}"

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
    end
  end
end
