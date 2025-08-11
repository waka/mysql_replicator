# frozen_string_literal: true

require 'socket'

module MysqlReplicator
  class Connection
    def initialize(config)
      @config = config
    end

    def connect
      @socket = TCPSocket.new(@config.host, @config.port)
      @socket.setsockopt(Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1)

      # receive handshake packet
      handshake_packet = read_packet
      parse_initial_handshake(handshake_packet)

      authenticate

      puts "Connected to MySQL server at #{@config.host}:#{@config.port}"
    end

    def authenticate
      # send authentication packet
      auth_packet = build_auth_packet
      send_packet(auth_packet)

      auth_response = read_packet
      raise MysqlReplicator::Error, 'Authentication failed' if auth_response[0].ord != 0x00
    end

    def close
      unless @socket
        puts 'TCPSocket is not connected'
        return
      end

      quit_packet = [0x01].pack('C')
      send_packet(quit_packet)

      @socket.close
      @socket = nil
    end

    def read_packet
      header = @socket.read(4)
      raise MysqlReplicator::Error, 'Failed to read packet header' if header.nil? || header.size != 4

      packet_length = header[0, 3].unpack('L<') & 0xFFFF
      sequence_id = header[3].ord
      puts "← Packet: length=#{packet_length}, sequence=#{sequence_id}"

      payload = @socket.read(packet_length)
      raise MysqlReplicator::Error, 'Failed to read packet payload' if payload.nil? || payload.size != packet_length

      puts "← Data: #{payload.unpack('C*').map { |b| format('%02x', b) }.join(' ')}"
      puts "← ASCII: #{payload.gsub(/[^\x20-\x7e]/, '.')}"
      puts ''

      { length: packet_length, sequence_id: sequence_id, payload: payload }
    end
  end
end
