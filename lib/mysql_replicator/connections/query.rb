# frozen_string_literal: true

module MysqlReplicator
  module Connections
    class Query
      def self.perform(connection, sql)
        query_payload = [0x03].pack('C') + sql.encode('utf-8')
        connection.send_packet(query_payload)

        response = connection.read_packet
        case response[:payload][0].unpack('C')[0]
        when 0x00 # OK
          parse_ok(response[:payload])
        when 0xFF # Error
          parse_error(response[:payload])
        else # Result set
          parse_result_set(connection, response[:payload])
        end
      end

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
          status_flags = payload[offset..(offset + 1)].unpack('v')[0]
          offset += 2
        else
          status_flags = nil
        end

        # warnings (2 bytes)
        if payload.length > offset + 3
          warnings = payload[(offset + 2)..(offset + 3)].unpack('v')[0]
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

      def self.parse_error(payload)
        error_code = payload[1..2].unpack('v')[0]
        sql_state_marker = payload[3].chr
        sql_state = payload[4..8]
        error_message = payload[9..]

        {
          error_code: error_code,
          sql_state_marker: sql_state_marker,
          sql_state: sql_state,
          error_message: error_message
        }
      end

      def self.parse_result_set(connection, payload)
        # Read columns definition
        columns = []
        column_count = length_encoded_integer(payload, 0)[:value]
        column_count.times do
          column_packet = connection.read_packet
          column_info = parse_column_definition(column_packet[:payload])
          columns << column_info
        end

        # EOF packet（at finish）
        connection.read_packet

        rows = []
        loop do
          row_packet = connection.read_packet

          # Check EOF packet
          if row_packet[:payload][0].unpack('C')[0] == 0xFE
            break
          end

          row_data = parse_row_data(row_packet[:payload], columns)
          rows << row_data
        end

        { columns: columns, rows: rows, row_count: rows.length }
      end

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
        charset = payload[offset..(offset + 1)].unpack('v')[0]
        offset += 2

        # column length (4 bytes)
        column_length = payload[offset..(offset + 3)].unpack('V')[0]
        offset += 4

        # type (1 byte)
        type = payload[offset].unpack('C')[0]

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

      def self.parse_row_data(payload, columns)
        first_byte = payload[0].unpack('C')[0]

        row = {}
        offset = 0

        columns.each do |column|
          if offset >= payload.length
            row[column[:name]] = nil
            next
          end

          if first_byte == 0xFB
            # NULL value
            row[column[:name]] = nil
            offset += 1
          else
            # row data (length-encoded string)
            value = length_encoded_string(payload, offset)
            row[column[:name]] = value[:value]
            offset += value[:bytes_read]
          end
        end

        row
      end

      def self.length_encoded_integer(payload, offset)
        first_byte = payload[offset].unpack('C')[0]

        case first_byte
        when 0..250
          { value: first_byte, bytes_read: 1 }
        when 0xFC
          value = payload[(offset + 1)..(offset + 2)].unpack('v')[0]
          { value: value, bytes_read: 3 }
        when 0xFD
          value = payload[(offset + 1)..(offset + 3)].unpack('V')[0] & 0xFFFFFF
          { value: value, bytes_read: 4 }
        when 0xFE
          value = payload[(offset + 1)..(offset + 8)].unpack('Q<')[0]
          { value: value, bytes_read: 9 }
        else # Included 0xFB
          { value: nil, bytes_read: 1 }
        end
      end

      def self.length_encoded_integer_size(value)
        return 1 if value.nil?
        return 1 if value <= 250
        return 3 if value <= 0xFFFF
        return 4 if value <= 0xFFFFFF

        9
      end

      def self.length_encoded_string(payload, offset)
        length_info = length_encoded_integer(payload, offset)
        return { value: nil, bytes_read: length_info[:bytes_read] } if length_info[:value].nil?

        string_start = offset + length_info[:bytes_read]
        string_end = string_start + length_info[:value] - 1
        value = payload[string_start..string_end]

        {
          value: value,
          bytes_read: length_info[:bytes_read] + length_info[:value]
        }
      end

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
