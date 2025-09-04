# frozen_string_literal: true

module MysqlReplicator
  # Binlog handler using MySQL Replication Protocol
  class BinlogClient
    def initialize(connection, server_id = 1001)
      @connection = connection
      @server_id = server_id
      @checksum_type = nil
      @replicationing = false
      @event_listener = nil
    end

    def start_replication(binlog_file = nil, binlog_position = 4, &block)
      @connection.connect unless @connection.connected?

      if binlog_file.nil? || binlog_position.nil?
        binlog_info = master_status
        binlog_file = binlog_info[:file]
        binlog_position = binlog_info[:position]
      end

      configure_binlog_checksum if @checksum_type.nil?
      register_as_slave
      start_binlog_dump(binlog_file, binlog_position)

      @event_listener = block if block_given?
      @replicationing = true
      handle_binlog_events
    end

    def stop_replication
      @replicationing = false
      unregister_as_slave
      @connection.close
      sleep 0.1
    end

    def restart_replication(binlog_file, binlog_position)
      stop_replication
      start_replication(binlog_file, binlog_position)
    end

    def master_status
      result = @connection.query('SHOW MASTER STATUS')
      result[:rows][0]
    end

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

    def configure_binlog_checksum
      result = @connection.query('SHOW VARIABLES LIKE "binlog_checksum"')
      @checksum_type = result[:rows][0][:value]

      case @checksum_type
      when 'NONE'
        # No checksum
      when 'CRC32'
        @connection.query('SET @master_binlog_checksum = "CRC32"')
        MysqlReplicator::Logger.debug 'Set binlog checksum to CRC32'
      else
        raise MysqlReplicator::Error, "Unknown binlog checksum type: #{@checksum_type}"
      end
    end

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

    def handle_binlog_events
      event_parser = MysqlReplicator::BinlogParsers::EventParser.new

      loop do
        break unless @replicationing

        packet = @connection.read_packet
        payload = packet[:payload]

        first_byte = payload[0].unpack('C')[0]

        case first_byte
        when 0x00
          binlog_event = event_parser.execute(payload[1..], @connection, @checksum_type == 'CRC32')
          MysqlReplicator::Logger.info "Binlog event: #{binlog_event}"

          case binlog_event[:event_type]
          when :QUERY, :WRITE_ROWS, :UPDATE_ROWS, :DELETE_ROWS
            @event_listener&.call(binlog_event)
          when :ROTATE
            MysqlReplicator::Logger.warn "Rotate binlog event: #{binlog_event}"
          when :UNKNOWN
            MysqlReplicator::Logger.warn "Unknown binlog event: #{binlog_event}"
          end
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
      rescue => e
        MysqlReplicator::Logger.error \
          "Error reading binlog events: #{e.message},\n" \
          "Backtrace: #{e.backtrace.first(5).join("\n")}"
        break
      end
    end
  end
end
