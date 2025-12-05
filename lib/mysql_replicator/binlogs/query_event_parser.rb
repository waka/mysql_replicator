# frozen_string_literal: true
# rbs_inline: enabled

module MysqlReplicator
  module Binlogs
    class QueryEventParser
      # @rbs!
      #   type execution = {
      #     thread_id: Integer,
      #     exec_time: Integer,
      #     error_code: Integer,
      #     database: String | nil,
      #     sql: String | nil
      #   }

      # @rbs payload: String
      # @rbs checksum_enabled: bool
      # @rbs return: execution
      def self.parse(payload, checksum_enabled)
        offset = 0

        thread_id = payload[offset, 4].unpack('V')[0]
        offset += 4

        exec_time = payload[offset, 4].unpack('V')[0]
        offset += 4

        db_len = payload[offset].unpack('C')[0]
        offset += 1

        error_code = payload[offset, 2].unpack('v')[0]
        offset += 2

        # Skip status variables
        status_vars_len = payload[offset, 2].unpack('v')[0]
        offset += 2
        if status_vars_len > 0
          offset += status_vars_len
        end

        # Database name (null-terminated)
        if db_len > 0
          database = payload[offset, db_len]
          offset += db_len
        end

        # Skip null terminator for database name
        if offset < payload.length && payload[offset] == "\x00"
          offset += 1
        end

        # The rest is the SQL query
        if offset < payload.length
          # Remove checksum if present (last 4 bytes)
          sql_end = checksum_enabled ? -5 : -1
          sql = payload[offset..sql_end]
        end

        {
          thread_id: thread_id,
          exec_time: exec_time,
          error_code: error_code,
          database: database,
          sql: sql
        }
      end
    end
  end
end
