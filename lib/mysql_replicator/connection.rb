# frozen_string_literal: true

require 'socket'
require_relative 'connections/auth'
require_relative 'connections/handshake'

module MysqlReplicator
  class Connection
    def initialize(host: 'localhost', port: 3306, user: 'root', password: '', database: '')
      @host = host
      @port = port
      @user = user
      @password = password
      @database = database

      @sequence_id = 0
      @connected = false

      @socket = TCPSocket.new(@host, @port)
      @socket.setsockopt(Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1)
    end

    def connected?
      @connected && @socket && !@socket.closed?
    end

    def connect
      handshake_response = MysqlReplicator::Connections::Handshake.perform(self)

      MysqlReplicator::Connections::Auth.perform(
        self,
        @user,
        @password,
        @database,
        handshake_response[:auth_plugin_name],
        handshake_response[:auth_plugin_data]
      )

      @connected = true
      MysqlReplicator::Logger.info "Connected to MySQL server at #{@host}:#{@port}"
    rescue => e
      close
      raise e
    end

    def close
      unless @socket.closed?
        MysqlReplicator::Logger.warn 'Connection is closed'
        return
      end

      quit_payload = [0x01].pack('C')
      send_packet(quit_payload)
      @socket.close
      @socket = nil
      @connected = false

      MysqlReplicator::Logger.info "Disconnected to MySQL server at #{@host}:#{@port}"
    end

    def read_packet
      header = @socket.read(4)
      if header.nil? || header.size != 4
        raise MysqlReplicator::Error, 'Failed to read packet header'
      end

      header_bytes = header.bytes

      MysqlReplicator::Logger.debug '===== Received packet ====='

      # Extract packet length and sequence ID
      # MySQL packet length is 3 bytes, so calculate manually
      packet_length = header_bytes[0] + (header_bytes[1] << 8) + (header_bytes[2] << 16)
      sequence_id = header_bytes[3]
      MysqlReplicator::Logger.debug "Received packet: length=#{packet_length}, sequence_id=#{sequence_id}"
      MysqlReplicator::Logger.debug "Header (hex): #{header.unpack('H*')[0].scan(/.{2}/).join(' ')}"

      # Check SequenceID
      if sequence_id != @sequence_id
        MysqlReplicator::Logger.warn "SequenceID is mismatch: received:#{sequence_id}, expected:#{@sequence_id})"
      end
      # Update SequenceID to next expected value
      @sequence_id = (sequence_id + 1) % 256

      payload = @socket.read(packet_length)
      if payload.nil? || payload.length != packet_length
        raise MysqlReplicator::Error,
              "Failed to read packet payload: expected #{packet_length} bytes, got #{payload&.length || 0}"
      end

      MysqlReplicator::Logger.debug "Data (hex): #{payload.unpack('C*').map { |b| format('%02x', b) }.join(' ')}"
      MysqlReplicator::Logger.debug "Data: #{payload.gsub(/[^\x20-\x7e]/, '.')}"

      { length: packet_length, sequence_id: sequence_id, payload: payload }
    end

    def send_packet(payload)
      packet_length = payload.length
      header = [packet_length].pack('V')[0..2] + [@sequence_id].pack('C')

      MysqlReplicator::Logger.debug '===== Send packet ====='
      MysqlReplicator::Logger.debug "Send packet: length=#{packet_length}, sequence_id=#{@sequence_id}"
      MysqlReplicator::Logger.debug "Header (hex): #{header.unpack('H*')[0].scan(/.{2}/).join(' ')}"
      MysqlReplicator::Logger.debug "Data (hex): #{payload.unpack('C*').map { |b| format('%02x', b) }.join(' ')}"
      MysqlReplicator::Logger.debug "Data: #{payload.gsub(/[^\x20-\x7e]/, '.')}"

      @socket.write(header + payload)
      @sequence_id = (@sequence_id + 1) % 256
    end

    def ping
      unless connected?
        MysqlReplicator::Logger.warn 'Connection is not connected'
        return
      end

      ping_payload = [COM_PING].pack('C')
      send_packet(ping_payload)

      response = read_packet
      response[:payload][0].unpack('C')[0] == 0x00
    end
  end
end
