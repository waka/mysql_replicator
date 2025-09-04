# frozen_string_literal: true

module MysqlReplicator
  module BinlogParsers
    class EventParser
      def initialize
        @stored_table_map = {}
      end

      def execute(payload, connection, checksum_enabled)
        timestamp = Time.at(payload[0, 4].unpack('V')[0])
        event_type = readable_event_type(payload[4].unpack('C')[0])
        server_id = payload[5, 4].unpack('V')[0]
        event_length = payload[9, 4].unpack('V')[0]
        next_position = payload[13, 4].unpack('V')[0]
        flags = payload[17, 2].unpack('v')[0]

        MysqlReplicator::Logger.debug \
          "Parsed binlog event: #{event_type}, timestamp: #{timestamp}, server_id: #{server_id}, " \
          "length: #{event_length}, next_position: #{next_position}, flags: #{flags}"

        execution = parse_execution_data(
          event_type,
          payload[19, -1],
          connection,
          checksum_enabled
        )

        {
          timestamp: timestamp,
          event_type: event_type,
          server_id: server_id,
          length: event_length,
          next_position: next_position,
          flags: flags,
          execution: execution
        }
      end

      # Basic event type identification
      def readable_event_type(event_type)
        case event_type
        when 2
          :QUERY
        when 4
          :ROTATE
        when 15
          :FORMAT_DESCRIPTION
        when 19
          :TABLE_MAP
        when 30
          :WRITE_ROWS
        when 31
          :UPDATE_ROWS
        when 32
          :DELETE_ROWS
        else
          :UNKNOWN
        end
      end

      def parse_execution_data(event_type, payload, connection, checksum_enabled)
        case event_type
        when :QUERY
          MysqlReplicator::BinlogParsers::QueryEventParser.parse(payload)
        when :ROTATE
          MysqlReplicator::BinlogParsers::RotateEventParser.parse(payload, checksum_enabled)
        when :FORMAT_DESCRIPTION
          MysqlReplicator::BinlogParsers::FormatDescriptionEventParser.parse(payload)
        when :TABLE_MAP
          result = MysqlReplicator::BinlogParsers::TableMapEventParser.parse(payload, connection)
          # Store in table map for future row events
          @stored_table_map[result[:table_id]] = result
        when :WRITE_ROWS
          MysqlReplicator::BinlogParsers::RowsEventParser.parse(
            payload,
            connection,
            checksum_enabled,
            @stored_table_map
          )
        when :UPDATE_ROWS
          # a
        when :DELETE_ROWS
          # a
        else
          {}
        end
      end
    end
  end
end
