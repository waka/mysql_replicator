# frozen_string_literal: true
# rbs_inline: enabled

module MysqlReplicator
  module Binlogs
    class EventParser
      # @rbs!
      #   type execution =
      #     MysqlReplicator::Binlogs::FormatDescriptionEventParser::execution |
      #     MysqlReplicator::Binlogs::QueryEventParser::execution |
      #     MysqlReplicator::Binlogs::RotateEventParser::execution |
      #     MysqlReplicator::Binlogs::RowsEventParser::execution |
      #     MysqlReplicator::Binlogs::TableMapEventParser::execution |
      #     MysqlReplicator::Binlogs::XidEventParser::execution |
      #     Hash[untyped, untyped]

      # @rbs!
      #   type binlogEvent = {
      #     timestamp: Time,
      #     event_type: Symbol,
      #     server_id: Integer,
      #     length: Integer,
      #     next_position: Integer,
      #     flags: Integer,
      #     execution: execution
      #   }

      # @rbs @stored_table_map: Hash[Integer, MysqlReplicator::Binlogs::TableMapEventParser::execution]

      # @rbs return: void
      def initialize
        @stored_table_map = {}
      end

      # @rbs payload: String
      # @rbs connection: MysqlReplicator::Connection
      # @rbs checksum_enabled: bool
      # @rbs return: binlogEvent
      def execute(payload, connection, checksum_enabled)
        offset = 0

        timestamp = Time.at(payload[offset, 4].unpack('V')[0])
        offset += 4
        event_type = readable_event_type(payload[offset].unpack('C')[0])
        offset += 1
        server_id = payload[offset, 4].unpack('V')[0]
        offset += 4
        event_length = payload[offset, 4].unpack('V')[0]
        offset += 4
        next_position = payload[offset, 4].unpack('V')[0]
        offset += 4
        flags = payload[offset, 2].unpack('v')[0]
        offset += 2

        payload_length = event_length - offset

        execution = parse_execution_data(
          event_type,
          payload[offset, payload_length],
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
      #
      # @rbs event_type: Integer
      # @rbs return: Symbol
      def readable_event_type(event_type)
        case event_type
        when 2
          :QUERY
        when 4
          :ROTATE
        when 15
          :FORMAT_DESCRIPTION
        when 16
          :XID
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

      # @rbs event_type: Symbol
      # @rbs payload: String
      # @rbs connection: MysqlReplicator::Connection
      # @rbs checksum_enabled: bool
      # @rbs return: execution
      def parse_execution_data(event_type, payload, connection, checksum_enabled)
        case event_type
        when :QUERY
          MysqlReplicator::Binlogs::QueryEventParser.parse(payload, checksum_enabled)
        when :ROTATE
          MysqlReplicator::Binlogs::RotateEventParser.parse(payload, checksum_enabled)
        when :FORMAT_DESCRIPTION
          MysqlReplicator::Binlogs::FormatDescriptionEventParser.parse(payload)
        when :TABLE_MAP
          result = MysqlReplicator::Binlogs::TableMapEventParser.parse(payload, connection)
          # Store in table map for future row events
          @stored_table_map[result[:table_id]] = result
          result
        when :WRITE_ROWS
          MysqlReplicator::Binlogs::RowsEventParser.parse(:WRITE_ROWS, payload, checksum_enabled, @stored_table_map)
        when :UPDATE_ROWS
          MysqlReplicator::Binlogs::RowsEventParser.parse(:UPDATE_ROWS, payload, checksum_enabled, @stored_table_map)
        when :DELETE_ROWS
          MysqlReplicator::Binlogs::RowsEventParser.parse(:DELETE_ROWS, payload, checksum_enabled, @stored_table_map)
        when :XID
          MysqlReplicator::Binlogs::XidEventParser.parse(payload)
        else
          {}
        end
      end
    end
  end
end
