# frozen_string_literal: true
# rbs_inline: enabled

require 'socket'

module MysqlReplicator
  class Connection
    # @rbs!
    #   type packet = {
    #     length: Integer,
    #     sequence_id: Integer,
    #     payload: String
    #   }

    # @rbs @host: String
    # @rbs @port: Integer
    # @rbs @user: String
    # @rbs @password: String
    # @rbs @database: String
    # @rbs @sequence_id: Integer
    # @rbs @connected: bool
    # @rbs @socket: TCPSocket
    # @rbs @handshake_info: MysqlReplicator::Connections::Handshake::handshake

    # @rbs! attr_reader host: String
    # @rbs! attr_reader port: Integer
    # @rbs! attr_reader user: String
    # @rbs! attr_reader password: String
    # @rbs! attr_reader database: String
    attr_reader :host, :port, :user, :password, :database

    # @rbs host: String
    # @rbs port: Integer
    # @rbs user: String
    # @rbs password: String
    # @rbs database: String
    # @rbs return: void
    def initialize(host: 'localhost', port: 3306, user: 'root', password: '', database: '')
      @host = host
      @port = port
      @user = user
      @password = password
      @database = database

      @sequence_id = 0
      @connected = false
    end

    # @rbs return: void
    def reset_sequence_id
      @sequence_id = 0
    end

    # @rbs return: -> bool
    def connected?
      @connected
    end

    # @rbs return: -> void
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

    # @rbs sql: String
    # @rbs return: MysqlReplicator::Connections::Query::queryResult | nil
    def query(sql)
      unless @connected
        MysqlReplicator::Logger.warn 'Connection is not connected'
        return
      end

      reset_sequence_id
      flush_socket_buffer

      MysqlReplicator::Connections::Query.execute(self, sql)
    end

    # @rbs return: 'PONG' | 'ERROR'
    def ping
      unless @connected
        MysqlReplicator::Logger.warn 'Connection is not connected'
        return 'ERROR'
      end

      reset_sequence_id

      ping_payload = [0x0E].pack('C')
      send_packet(ping_payload)

      response = read_packet
      success = MysqlReplicator::StringUtil.read_uint8(response[:payload][0]) == 0x00
      success ? 'PONG' : 'ERROR'
    end

    # @rbs return: void
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

      @socket.close unless @socket.closed?

      @connected = false
      MysqlReplicator::Logger.info "Disconnected to MySQL server at #{@host}:#{@port}"
    end

    # @rbs return: packet
    def read_packet
      if @socket.nil?
        raise MysqlReplicator::Error, 'TCPSocket is nil'
      end

      header = @socket.read(4)
      if header.nil? || header.length != 4
        raise MysqlReplicator::Error, 'Failed to read packet header'
      end

      # Little-endian 24-bit
      packet_length = MysqlReplicator::StringUtil.read_uint8(header[0]) |
                      (MysqlReplicator::StringUtil.read_uint8(header[1]) << 8) |
                      (MysqlReplicator::StringUtil.read_uint8(header[2]) << 16)
      sequence_id = MysqlReplicator::StringUtil.read_uint8(header[3])

      payload = @socket.read(packet_length)
      if payload.nil? || payload.length != packet_length
        raise MysqlReplicator::Error,
              "Failed to read packet payload: expected #{packet_length} bytes, got #{payload&.length || 0}"
      end

      packet = { length: packet_length, sequence_id: sequence_id, payload: payload }
      MysqlReplicator::Logger.debug "Received packet: #{packet.inspect}"

      # Update to next expected sequence ID
      @sequence_id = (sequence_id + 1) % 256

      {
        length: packet_length,
        sequence_id: sequence_id,
        payload: payload
      }
    end

    # @rbs payload: String
    # @rbs return: void
    def send_packet(payload)
      if @socket.nil?
        raise MysqlReplicator::Error, 'TCPSocket is nil'
      end

      packet_length = payload.length
      header = ([packet_length].pack('V')[0..2] || '') + [@sequence_id].pack('C').to_s
      @socket.write(header + payload)

      packet = { length: packet_length, sequence_id: @sequence_id, payload: payload }
      MysqlReplicator::Logger.debug "Sent packet: #{packet.inspect}"
    end

    # @rbs return: void
    def flush_socket_buffer
      return if @socket.nil?

      flushed_data = ''

      begin
        # Read all unread data in non-blocking mode
        while @socket.wait_readable(0)
          data = @socket.read_nonblock(1024)
          flushed_data += data
          MysqlReplicator::Logger.debug \
            "Found unread data: #{MysqlReplicator::StringUtil.read_array_from_int8(data).map { |b| format('%02X', b) }.join(' ')}"
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

    # @rbs return: Integer
    def connection_id
      @handshake_info[:connection_id]
    end

    # @rbs return: MysqlReplicator::Connection
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
