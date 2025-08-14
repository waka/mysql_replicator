# frozen_string_literal: true

require 'socket'
require_relative 'connections/auth'
require_relative 'connections/handshake'

module MysqlReplicator
  class Connection
    def initialize(host: 'localhost', port: 3306, user: 'root', password: '')
      @host = host
      @port = port
      @user = user
      @password = password

      @socket = TCPSocket.new(@host, @port)
      @socket.setsockopt(Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1)
    end

    def connect
      handshake_response = MysqlReplicator::Connections::Handshake.perform(self)

      MysqlReplicator::Connections::Auth.perform(
        self,
        @user,
        @password,
        handshake_response[:auth_plugin_name],
        handshake_response[:auth_plugin_data]
      )

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
      MysqlReplicator::Logger.info "Disconnected to MySQL server at #{@host}:#{@port}"
    end

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

      MysqlReplicator::Logger.debug "Data (hex): #{payload.unpack('C*').map { |b| format('%02x', b) }.join(' ')}"
      MysqlReplicator::Logger.debug "Data: #{payload.gsub(/[^\x20-\x7e]/, '.')}"

      payload
    end

    def send_packet(packet)
      @socket.write(packet)
      @socket.flush
    end
  end
end
