# frozen_string_literal: true

require 'socket'

module MysqlReplicator
  class Connection
    def initialize(host:, port:, user:, password:)
      @host = host || 'localhost'
      @port = port || 3306
      @user = user || 'root'
      @password = password || ''
    end

    def connect
      @socket = TCPSocket.new(@host, @port)
      @socket.setsockopt(Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1)

      handshake_response = handshake
      authenticate(handshake_response[:auth_plugin_name], handshake_response[:auth_plugin_data])

      MysqlReplicator::Logger.info "Connected to MySQL server at #{@host}:#{@port}"
    rescue => e
      close
      raise e
    end

    def close
      unless @socket
        MysqlReplicator::Logger.warn 'TCPSocket is not connected'
        return
      end

      quit_packet = [0x01].pack('C')
      send_packet(quit_packet)
      @socket.close
      @socket = nil
      MysqlReplicator::Logger.warn 'TCPSocket is closed'
    end

    def handshake
      handshake_packet = read_packet
      payload = handshake_packet[:payload]

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

      # Legacy MySQL is end here
      if offset >= payload.length
        return { auth_plugin_name: 'mysql_native_password', auth_plugin_data: auth_plugin_data_part1 }
      end

      # After MySQL 8.0, additional authentication plugin information is included

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
      unless ['caching_sha2_password', 'mysql_native_password', 'sha256_password'].include?(auth_plugin_name)
        raise MysqlReplicator::Error, 'Not supported Custom authentication plugin'
      end

      {
        auth_plugin_name: auth_plugin_name,
        auth_plugin_data: auth_plugin_data_part1 + auth_plugin_data_part2[0..11]
      }
    end

    def authenticate(auth_plugin_name, auth_plugin_data)
      auth_packet = case auth_plugin_name
                    when 'caching_sha2_password'
                      MysqlReplicator::AuthMethods::CachingSha2Password.build_auth_packet(@user, @password,
                                                                                          auth_plugin_data)
                    when 'mysql_native_password'
                      MysqlReplicator::AuthMethods::MysqlNativePassword.build_auth_packet(@user, @password,
                                                                                          auth_plugin_data)
                    end
      send_packet(auth_packet)

      auth_response = read_packet
      raise MysqlReplicator::Error, 'Authentication failed' if auth_response[0].ord != 0x00
    end

    private

    def read_packet
      header = @socket.read(4)
      if header.nil? || header.size != 4
        raise MysqlReplicator::Error, 'Failed to read packet header'
      end

      header_bytes = header.bytes

      # Extract packet length and sequence ID
      # MySQL packet length is 3 bytes, so calculate manually
      packet_length = header_bytes[0] + (header_bytes[1] << 8) + (header_bytes[2] << 16)
      sequence_id = header_bytes[3]
      MysqlReplicator::Logger.debug "Packet: length=#{packet_length}, sequence_id=#{sequence_id}"
      MysqlReplicator::Logger.debug "Header (hex): #{header.unpack('H*')[0].scan(/.{2}/).join(' ')}"

      payload = @socket.read(packet_length)
      if payload.nil? || payload.size != packet_length
        raise MysqlReplicator::Error,
              "Failed to read packet payload: expected #{packet_length} bytes, got #{payload&.size || 0}"
      end

      MysqlReplicator::Logger.debug "Data: #{payload.unpack('C*').map { |b| format('%02x', b) }.join(' ')}"
      MysqlReplicator::Logger.debug "Data (hex): #{payload.gsub(/[^\x20-\x7e]/, '.')}"

      { length: packet_length, sequence_id: sequence_id, payload: payload }
    end

    def send_packet(packet)
      @socket.write(packet)
      @socket.flush
    end
  end
end
