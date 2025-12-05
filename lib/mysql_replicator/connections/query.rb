# frozen_string_literal: true
# rbs_inline: enabled

module MysqlReplicator
  module Connections
    class Query
      # @rbs!
      #   type columnData = {
      #     catalog: String,
      #     schema: String,
      #     table: String,
      #     org_table: String,
      #     name: String,
      #     org_name: String,
      #     charset: Integer,
      #     column_length: Integer,
      #     type: String
      #   }

      # @rbs!
      #   type queryResultOk = {
      #     affected_rows: Integer | nil,
      #     insert_id: Integer | nil,
      #     status_flags: Integer | nil,
      #     warnings: Integer | nil,
      #     info_message: String | nil
      #   }

      # @rbs!
      #   type queryResultError = {
      #     error_code: Integer,
      #     sql_state_marker: String,
      #     sql_state: String | nil,
      #     error_message: String | nil
      #   }

      # @rbs!
      #   type queryResultSet = {
      #     columns: Array[columnData],
      #     rows: Array[Hash[Symbol, String | nil]],
      #     row_count: Integer
      #   }

      # @rbs!
      #   type queryResult = queryResultOk | queryResultError | queryResultSet

      # @rbs connection: MysqlReplicator::Connection
      # @rbs sql: String
      # @rbs return: queryResult
      def self.execute(connection, sql)
        query_payload = [0x03].pack('C') + sql.encode('utf-8')
        connection.send_packet(query_payload)

        response = connection.read_packet
        case MysqlReplicator::StringUtil.read_uint8(response[:payload][0])
        when 0x00 # OK
          parse_ok(response[:payload])
        when 0xFF # Error
          parse_error(response[:payload])
        else # Result set
          parse_result_set(connection, response[:payload])
        end
      end

      # @rbs payload: String
      # @rbs return: queryResultOk
      def self.parse_ok(payload)
        offset = 1 # Skip 0x00

        # affected_rows (length-encoded integer)
        affected_rows = length_encoded_integer(payload, offset)[:value]
        offset += length_encoded_integer_size(affected_rows)

        # insert_id (length-encoded integer)
        insert_id = length_encoded_integer(payload, offset)[:value]
        offset += length_encoded_integer_size(insert_id)

        # status_flags (2 bytes)
        if payload.length > offset + 1
          status_flags = MysqlReplicator::StringUtil.read_uint16(payload[offset..(offset + 1)])
          offset += 2
        else
          status_flags = nil
        end

        # warnings (2 bytes)
        if payload.length > offset + 3
          warnings = MysqlReplicator::StringUtil.read_uint16(payload[(offset + 2)..(offset + 3)])
          offset += 2
        else
          warnings = nil
        end

        # info_message (all the rest)
        info_message = payload.length > offset + 4 ? payload[(offset + 4)..] : nil

        {
          affected_rows: affected_rows,
          insert_id: insert_id,
          status_flags: status_flags,
          warnings: warnings,
          info_message: info_message
        }
      end

      # @rbs payload: String
      # @rbs return: queryResultError
      def self.parse_error(payload)
        error_code = MysqlReplicator::StringUtil.read_uint16(payload[1..2])
        sql_state_marker = (payload[3] || '').chr
        sql_state = payload[4..8] || nil
        error_message = payload[9..] || nil

        {
          error_code: error_code,
          sql_state_marker: sql_state_marker,
          sql_state: sql_state,
          error_message: error_message
        }
      end

      # @rbs connection: MysqlReplicator::Connection
      # @rbs payload: String
      # @rbs return: queryResultSet
      def self.parse_result_set(connection, payload)
        # Read columns definition
        columns = []
        column_count = length_encoded_integer(payload, 0)[:value].to_i
        column_count.times do
          column_packet = connection.read_packet
          column_info = parse_column_definition(column_packet[:payload])
          columns << column_info
        end

        # EOF packet（at finish）
        connection.read_packet

        rows = [] #: Array[Hash[Symbol, String | nil]]

        loop do
          row_packet = connection.read_packet

          # Check EOF packet
          if MysqlReplicator::StringUtil.read_uint8(row_packet[:payload][0]) == 0xFE
            break
          end

          row_data = parse_row_data(row_packet[:payload], columns)
          rows << row_data
        end

        { columns: columns, rows: rows, row_count: rows.length }
      end

      # @rbs payload: String
      # @rbs return: columnData
      def self.parse_column_definition(payload)
        offset = 0

        # catalog (length-encoded string)
        catalog = length_encoded_string(payload, offset)
        offset += catalog[:bytes_read]

        # schema (length-encoded string)
        schema = length_encoded_string(payload, offset)
        offset += schema[:bytes_read]

        # table (length-encoded string)
        table = length_encoded_string(payload, offset)
        offset += table[:bytes_read]

        # org_table (length-encoded string)
        org_table = length_encoded_string(payload, offset)
        offset += org_table[:bytes_read]

        # name (length-encoded string)
        name = length_encoded_string(payload, offset)
        offset += name[:bytes_read]

        # org_name (length-encoded string)
        org_name = length_encoded_string(payload, offset)
        offset += org_name[:bytes_read]

        # length of fixed-length fields (1 byte)
        offset += 1

        # character set (2 bytes)
        charset = MysqlReplicator::StringUtil.read_uint16(payload[offset..(offset + 1)])
        offset += 2

        # column length (4 bytes)
        column_length = MysqlReplicator::StringUtil.read_uint32(payload[offset..(offset + 3)])
        offset += 4

        # type (1 byte)
        type = MysqlReplicator::StringUtil.read_uint8(payload[offset])

        {
          catalog: catalog[:value],
          schema: schema[:value],
          table: table[:value],
          org_table: org_table[:value],
          name: name[:value],
          org_name: org_name[:value],
          charset: charset,
          column_length: column_length,
          type: type_to_string(type)
        }
      end

      # @rbs payload: String
      # @rbs columns: Array[columnData]
      # @rbs return: Hash[Symbol, String | nil]
      def self.parse_row_data(payload, columns)
        first_byte = MysqlReplicator::StringUtil.read_uint8(payload[0])

        row = {} #: Hash[Symbol, String | nil]
        offset = 0

        columns.each do |column|
          column_name_key = column[:name].downcase.to_sym

          if offset >= payload.length
            row[column_name_key] = nil
            next
          end

          if first_byte == 0xFB
            # NULL value
            row[column_name_key] = nil
            offset += 1
          else
            # row data (length-encoded string)
            value = length_encoded_string(payload, offset)
            row[column_name_key] = value[:value]
            offset += value[:bytes_read]
          end
        end

        row
      end

      # @rbs payload: String
      # @rbs offset: Integer
      # @rbs return: { value: Integer | nil, bytes_read: Integer }
      def self.length_encoded_integer(payload, offset)
        first_byte = MysqlReplicator::StringUtil.read_uint8(payload[offset])

        case first_byte
        when 0..250
          { value: first_byte, bytes_read: 1 }
        when 0xFC
          value = MysqlReplicator::StringUtil.read_uint16(payload[(offset + 1)..(offset + 2)])
          { value: value, bytes_read: 3 }
        when 0xFD
          value = MysqlReplicator::StringUtil.read_uint32(payload[(offset + 1)..(offset + 3)]) & 0xFFFFFF
          { value: value, bytes_read: 4 }
        when 0xFE
          value = MysqlReplicator::StringUtil.read_uint64(payload[(offset + 1)..(offset + 8)])
          { value: value, bytes_read: 9 }
        else # Included 0xFB
          { value: nil, bytes_read: 1 }
        end
      end

      # @rbs value: Integer | nil
      # @rbs return: Integer
      def self.length_encoded_integer_size(value)
        return 1 if value.nil?
        return 1 if value <= 250
        return 3 if value <= 0xFFFF
        return 4 if value <= 0xFFFFFF

        9
      end

      # @rbs payload: String
      # @rbs offset: Integer
      # @rbs return { value: String, bytes_read: Integer }
      def self.length_encoded_string(payload, offset)
        length_info = length_encoded_integer(payload, offset)
        return { value: '', bytes_read: length_info[:bytes_read] } if length_info[:value].nil?

        string_start = offset + length_info[:bytes_read]
        string_end = string_start + length_info[:value] - 1
        value = payload[string_start..string_end] || ''

        {
          value: value,
          bytes_read: length_info[:bytes_read] + length_info[:value]
        }
      end

      # @rbs type: Integer | Float | String | nil
      # @rbs return: String
      def self.type_to_string(type)
        case type
        when 0x00 then 'DECIMAL'
        when 0x01 then 'TINYINT'
        when 0x02 then 'SMALLINT'
        when 0x03 then 'INT'
        when 0x04 then 'FLOAT'
        when 0x05 then 'DOUBLE'
        when 0x06 then 'NULL'
        when 0x07 then 'TIMESTAMP'
        when 0x08 then 'BIGINT'
        when 0x09 then 'MEDIUMINT'
        when 0x0A then 'DATE'
        when 0x0B then 'TIME'
        when 0x0C then 'DATETIME'
        when 0x0D then 'YEAR'
        when 0x0F then 'VARCHAR'
        when 0xF6 then 'NEWDECIMAL'
        when 0xFC then 'BLOB'
        when 0xFD then 'VAR_STRING'
        when 0xFE then 'STRING'
        else "UNKNOWN(#{type})"
        end
      end
    end
  end
end
