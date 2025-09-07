# frozen_string_literal: true

module MysqlReplicator
  module Binlogs
    class RowsEventParser
      def self.parse(event_type, payload, checksum_enabled, table_map)
        offset = 0

        # Table ID (6 bytes)
        table_id = to_little_endian(payload[0, 6].unpack('C*'))
        offset += 6

        _flags = payload[offset, 2].unpack('v')[0]
        offset += 2

        extra_data_length = payload[offset, 2].unpack('v')[0]
        offset += 2
        _extra_data = nil
        if extra_data_length > 2
          _extra_data = payload[offset, extra_data_length - 2]
          offset += extra_data_length - 2
        end

        # Variable part starts here
        table_def = table_map[table_id]

        # Column count (variable length encoded)
        column_count, bytes_read = read_variable_length_integer(payload, offset)
        offset += bytes_read

        # Columns present bitmap (before image for UPDATE)
        # For WRITE_ROWS, this is the columns present bitmap
        bitmap_bytes = (column_count + 7) / 8
        columns_present_before = payload[offset, bitmap_bytes]
        offset += bitmap_bytes

        # For UPDATE events, there's also an "after" bitmap
        columns_present_after = nil
        if event_type == :UPDATE_ROWS
          columns_present_after = payload[offset, bitmap_bytes]
          offset += bitmap_bytes
        end

        rows = []
        while offset < payload.length - (checksum_enabled ? 4 : 0)
          case event_type
          when :WRITE_ROWS
            row_data = parse_single_row(payload, offset, table_def, columns_present_before)
            break if row_data.nil?

            rows << { type: :insert, after: row_data[:row] }
            offset = row_data[:next_offset]
          when :DELETE_ROWS
            row_data = parse_single_row(payload, offset, table_def, columns_present_before)
            break if row_data.nil?

            rows << { type: :delete, before: row_data[:row] }
            offset = row_data[:next_offset]
          when :UPDATE_ROWS
            # Before image
            before_data = parse_single_row(payload, offset, table_def, columns_present_before)
            break if before_data.nil?

            offset = before_data[:next_offset]

            # After image
            after_data = parse_single_row(payload, offset, table_def, columns_present_after)
            break if after_data.nil?

            rows << { type: :update, before: before_data[:row], after: after_data[:row] }
            offset = after_data[:next_offset]
          end
        end

        {
          table_id: table_id,
          database: table_def[:database],
          table: table_def[:table],
          columns: table_def[:columns],
          column_count: column_count,
          rows: rows
        }
      end

      def self.to_little_endian(bytes)
        result = 0
        bytes.each_with_index do |byte, i|
          result |= (byte << (i * 8))
        end
        result
      end

      def self.read_variable_length_integer(payload, offset)
        first_byte = payload[offset, 1].unpack('C')[0]

        if first_byte < 0xfb
          [first_byte, 1]
        elsif first_byte == 0xfc
          [payload[offset + 1, 2].unpack('v')[0], 3]
        elsif first_byte == 0xfd
          [payload[offset + 1, 3].unpack('V')[0] & 0xffffff, 4]
        elsif first_byte == 0xfe
          [payload[offset + 1, 8].unpack('Q<')[0], 9]
        else
          [0, 1]
        end
      end

      def self.parse_single_row(payload, offset, table_def, columns_present)
        # NULL bitmap
        null_bitmap_bytes = (table_def[:columns].length + 7) / 8
        return nil if offset + null_bitmap_bytes > payload.length

        null_bitmap = payload[offset, null_bitmap_bytes]
        offset += null_bitmap_bytes

        row = {}

        table_def[:columns].each_with_index do |column_def, index|
          if column_present?(columns_present, index) && !column_null?(null_bitmap, index)
            result = MysqlReplicator::Binlogs::ColumnParser.parse(payload[offset..], column_def)
            row[column_def[:column_name].to_sym] = {
              value: result[:value],
              type: column_def[:data_type],
              ordinal_position: column_def[:ordinal_position],
              enum_values: column_def[:enum_values],
              primary_key: column_def[:primary_key],
              nullable: column_def[:nullable]
            }
            offset += result[:byte_consumed]
          elsif column_null?(null_bitmap, index)
            row[column_def[:column_name].to_sym] = {
              value: nil,
              type: column_def[:data_type],
              ordinal_position: column_def[:ordinal_position],
              enum_values: column_def[:enum_values],
              primary_key: column_def[:primary_key],
              nullable: column_def[:nullable]
            }
          else
            MysqlReplicator::Logger.debug \
              "#{column_def[:column_name]} (#{column_def[:data_type]}) is not present"
          end
        end

        { row: row, next_offset: offset }
      end

      def self.column_present?(columns_present, column_index)
        byte_index = column_index / 8
        bit_index = column_index % 8
        return false if byte_index >= columns_present.length

        byte_value = columns_present[byte_index].unpack('C')[0]
        (byte_value & (1 << bit_index)) != 0
      end

      def self.column_null?(null_bitmap, column_index)
        byte_index = column_index / 8
        bit_index = column_index % 8
        return false if byte_index >= null_bitmap.length

        byte_value = null_bitmap[byte_index].unpack('C')[0]
        (byte_value & (1 << bit_index)) != 0
      end
    end
  end
end
