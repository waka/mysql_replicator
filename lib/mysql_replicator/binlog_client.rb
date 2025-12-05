# frozen_string_literal: true
# rbs_inline: enabled

module MysqlReplicator
  # Binlog handler using MySQL Replication Protocol
  class BinlogClient
    # @rbs @connection: MysqlReplicator::Connection
    # @rbs @server_id: Integer
    # @rbs @checksum_type: String?
    # @rbs @event_listener: ^(MysqlReplicator::Binlogs::EventParser::binlogEvent) -> untyped | nil

    # @rbs! attr_reader connection: MysqlReplicator::Connection
    attr_reader :connection

    # @rbs connection: MysqlReplicator::Connection
    # @rbs server_id: Integer
    # @rbs return void
    def initialize(connection, server_id = 1001)
      @connection = connection
      @server_id = server_id
      @checksum_type = nil
    end

    # @rbs &block: { (MysqlReplicator::Binlogs::EventParser::binlogEvent) -> untyped | nil }
    # @rbs return: void
    def on(&block)
      @event_listener = block
    end

    # @rbs return: void
    def start_replication
      @connection.connect unless @connection.connected?

      binlog_info = master_status
      binlog_file = binlog_info[:file]
      binlog_position = binlog_info[:position]

      configure_binlog_checksum if @checksum_type.nil?
      register_as_slave
      start_binlog_dump(binlog_file, binlog_position)

      begin
        handle_binlog_events
      rescue Interrupt
        stop_replication
      rescue => e
        MysqlReplicator::Logger.error \
          "Unexpected error: #{e.message},\n" \
          "Backtrace: #{e.backtrace.first(5).join("\n")}"

        stop_replication
      end
    end

    # @rbs return: void
    def stop_replication
      @connection.flush_socket_buffer
      unregister_as_slave
      @connection.close
    end

    # @rbs return: { file: String, position: Integer }
    def master_status
      result = @connection.query('SHOW MASTER STATUS')
      row = result[:rows][0]
      { file: row[:file].to_s, position: row[:position].to_i }
    end

    # @rbs return: void
    def register_as_slave
      @connection.reset_sequence_id

      # Payload of COM_REGISTER_SLAVE packet
      payload = [0x15].pack('C')
      # Server ID (4 bytes)
      payload += [@server_id].pack('V')
      # Hostname (empty string but properly formatted)
      hostname = ''
      payload += [hostname.length].pack('C') + hostname
      # Username (empty string but properly formatted)
      username = ''
      payload += [username.length].pack('C') + username
      # Password (empty string but properly formatted)
      password = ''
      payload += [password.length].pack('C') + password
      # MySQL port
      payload += [@connection.port].pack('V')
      # Replication rank = 0 (unused)
      payload += [0].pack('V')
      # Master ID = 0 (unused)
      payload += [0].pack('V')

      @connection.send_packet(payload)

      response = @connection.read_packet
      if response[:payload][0].unpack('C')[0] != 0x00
        raise MysqlReplicator::Error,
          'Failed to register as slave ' \
          "error code = #{response[:payload][1, 2].unpack('v')[0]}, " \
          "error message = #{response[:payload][9..]}"
      end

      MysqlReplicator::Logger.info 'Successfully registered as slave'
    end

    # @rbs return: void
    def unregister_as_slave
      @connection.reset_sequence_id

      # Payload of COM_UNREGISTER_SLAVE packet
      payload = [0x1B].pack('C')
      # Connection ID (4 bytes)
      payload += [@connection.connection_id].pack('V')

      @connection.send_packet(payload)

      response = @connection.read_packet
      if response[:payload][0].unpack('C')[0] != 0x00
        raise MysqlReplicator::Error,
          'Failed to unregister as slave ' \
          "error code = #{response[:payload][1, 2].unpack('v')[0]}, " \
          "error message = #{response[:payload][9..]}"
      end

      MysqlReplicator::Logger.info 'Successfully unregistered as slave'
    end

    # @rbs return: void
    def configure_binlog_checksum
      result = @connection.query('SHOW VARIABLES LIKE "binlog_checksum"')
      @checksum_type = result[:rows][0][:value]

      case @checksum_type
      when 'NONE'
        # No checksum
        MysqlReplicator::Logger.debug 'Set binlog checksum to NONE'
      when 'CRC32'
        @connection.query('SET @master_binlog_checksum = "CRC32"')
        MysqlReplicator::Logger.debug 'Set binlog checksum to CRC32'
      else
        raise MysqlReplicator::Error, "Unknown binlog checksum type: #{@checksum_type}"
      end
    end

    # @rbs binlog_file: String
    # @rbs binlog_position: Integer
    # @rbs return: void
    def start_binlog_dump(binlog_file, binlog_position)
      @connection.reset_sequence_id

      # Payload of COM_BINLOG_DUMP packet
      payload = [0x12].pack('C')
      # Binlog position (4 bytes)
      payload += [Integer(binlog_position)].pack('V')
      # Flags (2 bytes)
      payload += [0].pack('v')
      # Slave server ID (4 bytes)
      payload += [@server_id].pack('V')
      # Binlog filename
      payload += binlog_file

      @connection.send_packet(payload)

      MysqlReplicator::Logger.info \
        "Started binlog dump from #{binlog_file} at position #{binlog_position}"
    end

    # @rbs return: void
    def handle_binlog_events
      event_parser = MysqlReplicator::Binlogs::EventParser.new

      loop do
        packet = @connection.read_packet
        payload = packet[:payload]

        first_byte = payload[0].unpack('C')[0]

        case first_byte
        when 0x00
          binlog_event = event_parser.execute(payload[1..], @connection, @checksum_type == 'CRC32')

          case binlog_event[:event_type]
          when :QUERY, :WRITE_ROWS, :UPDATE_ROWS, :DELETE_ROWS
            @event_listener&.call(binlog_event)
          end
          MysqlReplicator::Logger.debug "Binlog event: #{binlog_event}"
        when 0xFF
          MysqlReplicator::Logger.error \
            "Binlog event error: #{payload[1, 2].unpack('v')[0]} - #{payload[3..]}"
          break
        when 0xFE
          MysqlReplicator::Logger.error 'Received EOF packet - binlog stream ended'
          break
        else
          MysqlReplicator::Logger.error "Unexpected packet type: 0x#{first_byte.to_s(16)}"
          break
        end
      end
    end
  end
end
