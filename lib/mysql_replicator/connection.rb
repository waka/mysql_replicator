# frozen_string_literal: true

require 'socket'

module MysqlReplicator
  class Connection
    attr_reader :host, :port, :user, :password, :database

    def initialize(host: 'localhost', port: 3306, user: 'root', password: '', database: '')
      @host = host
      @port = port
      @user = user
      @password = password
      @database = database

      @socket = nil
      @sequence_id = 0
      @connected = false
      @handshake_info = nil
    end

    def reset_sequence_id
      @sequence_id = 0
    end

    def connected?
      @connected
    end

    def connect
      if @connected
        MysqlReplicator::Logger.warn 'Connection is already connected'
        return
      end

      @socket = TCPSocket.new(@host, @port)
      @socket.setsockopt(Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1)

      @handshake_info = MysqlReplicator::Connections::Handshake.execute(self)
      MysqlReplicator::Connections::Auth.execute(self, @user, @password, @database, @handshake_info)

      @connected = true
      MysqlReplicator::Logger.info "Connected to MySQL server at #{@host}:#{@port}"
    rescue => e
      close
      raise e
    end

    def query(sql)
      unless @connected
        MysqlReplicator::Logger.warn 'Connection is not connected'
        return
      end

      reset_sequence_id
      flush_socket_buffer

      MysqlReplicator::Connections::Query.execute(self, sql)
    end

    def ping
      unless @connected
        MysqlReplicator::Logger.warn 'Connection is not connected'
        return
      end

      reset_sequence_id

      ping_payload = [0x0E].pack('C')
      send_packet(ping_payload)

      response = read_packet
      success = response[:payload][0].unpack('C')[0] == 0x00
      success ? 'PONG' : 'ERROR'
    end

    def close
      if !@connected && (@socket.nil? || @socket.closed?)
        MysqlReplicator::Logger.warn 'Connection is not connected'
        return
      end

      reset_sequence_id

      if @connected
        quit_payload = [0x01].pack('C')
        send_packet(quit_payload)
      end

      if @socket && !@socket.closed?
        @socket.close
        @socket = nil
      end

      @connected = false
      MysqlReplicator::Logger.info "Disconnected to MySQL server at #{@host}:#{@port}"
    end

    def read_packet
      header = @socket.read(4)
      if header.nil? || header.length != 4
        raise MysqlReplicator::Error, 'Failed to read packet header'
      end

      # Little-endian 24-bit
      packet_length = header[0].unpack('C')[0] |
                      (header[1].unpack('C')[0] << 8) |
                      (header[2].unpack('C')[0] << 16)
      sequence_id = header[3].unpack('C')[0]

      payload = @socket.read(packet_length)
      if payload.nil? || payload.length != packet_length
        raise MysqlReplicator::Error,
              "Failed to read packet payload: expected #{packet_length} bytes, got #{payload&.length || 0}"
      end

      packet = { length: packet_length, sequence_id: sequence_id, payload: payload }
      MysqlReplicator::Logger.debug "Received packet: #{packet.inspect}"

      # Update to next expected sequence ID
      @sequence_id = (sequence_id + 1) % 256

      packet
    end

    def send_packet(payload)
      packet_length = payload.length
      header = [packet_length].pack('V')[0..2] + [@sequence_id].pack('C')
      @socket.write(header + payload)

      packet = { length: packet_length, sequence_id: @sequence_id, payload: payload }
      MysqlReplicator::Logger.debug "Sent packet: #{packet.inspect}"
    end

    def flush_socket_buffer
      flushed_data = ''

      begin
        # Read all unread data in non-blocking mode
        while @socket.ready?
          data = @socket.read_nonblock(1024)
          flushed_data += data
          MysqlReplicator::Logger.debug \
            "Found unread data: #{data.unpack('C*').map { |b| format('%02X', b) }.join(' ')}"
        end

        sleep 0.1
      rescue IO::WaitReadable
        # Not at all if no data
      rescue => e
        MysqlReplicator::Logger.error "Buffer clear error: #{e.message}"
      end

      return if flushed_data.empty?

      MysqlReplicator::Logger.debug "#{flushed_data.length} bytes of unread data cleared"
    end

    def connection_id
      @handshake_info[:connection_id]
    end

    def dup
      new_connection = self.class.new(
        host: @host,
        port: @port,
        user: @user,
        password: @password,
        database: @database
      )
      new_connection.connect
      new_connection
    end
  end
end
