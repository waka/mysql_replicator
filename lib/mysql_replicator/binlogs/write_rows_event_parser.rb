# frozen_string_literal: true

require 'stringio'

module MysqlReplicator
  module Binlogs
    class WriteRowsEventParser
      # @param payload [String] the event payload
      # @param checksum_enabled [Boolean] whether checksum is enabled
      # @param table_map [Hash] the table map for resolving table definitions
      # @return [Hash] parsed write rows event data
      def self.parse(payload, checksum_enabled, table_map)
        io = StringIO.new(payload)
        io.set_encoding(Encoding::BINARY)

        # 4bytes checksum at the end if CRC32 checksum is enabled
        payload_size = checksum_enabled ? payload.bytesize - 4 : payload.bytesize

        # Table ID (6 bytes)
        table_id = StringIOUtil.read_uint48(io)
        # Flags (2 bytes)
        flags = StringIOUtil.read_uint16(io)
        # Extra data length (2 bytes)
        extra_data_length = StringIOUtil.read_uint16(io)
        # Skip extra data if present
        io.read(extra_data_length - 2) if extra_data_length > 2

        # Column count (variable length encoded)
        column_count = read_packed_integer(io)

        # Columns present bitmap
        # A bitmap indicating which columns are present in the row data
        columns_present_bitmap = io.read((column_count + 7) / 8).unpack('C*')

        # Parse row data
        table_def = table_map[table_id]
        rows = []
        while io.pos < payload_size
          row = parse_row(io, column_count, columns_present_bitmap, table_def)
          rows << row
        end

        {
          table_id: table_id,
          flags: flags,
          extra_data_length: extra_data_length,
          column_count: column_count,
          columns_present_bitmap: columns_present_bitmap,
          rows: rows
        }
      end

      def self.parse_row(io, column_count, columns_present_bitmap, table_def)
        # Null bitmap
        # A bitmap indicating which columns are NULL
        present_count = count_bits(columns_present_bitmap, column_count)
        null_bitmap_size = (present_count + 7) / 8
        null_bitmap = io.read(null_bitmap_size).unpack('C*')
        null_bit_index = 0

        row = []
        table_def[:columns].each_with_index do |column_def, column_index|
          unless bit_set?(columns_present_bitmap, column_index)
            next
          end

          column_name = column_def[:column_name]

          # Check if the column is NULL
          value = if bit_set?(null_bitmap, null_bit_index)
                    nil
                  else
                    MysqlReplicator::Binlogs::ColumnParser.parse(io, column_def)
                  end
          null_bit_index += 1

          row << {
            ordinal_position: column_def[:ordinal_position].to_i,
            data_type: column_def[:data_type],
            column_name: column_name,
            value: value,
            primary_key: column_def[:primary_key]
          }
        end

        row
      end

      def self.read_packed_integer(io)
        first = StringIOUtil.read_uint8(io)
        case first
        when 0..250
          first
        when 252
          StringIOUtil.read_uint16(io)
        when 253
          StringIOUtil.read_uint24(io)
        when 254
          StringIOUtil.read_uint64(io)
        else
          raise "Invalid packed integer: #{first}"
        end
      end

      def self.bit_set?(bitmap, index)
        byte_index = index / 8
        bit_index = index % 8
        (bitmap[byte_index] & (1 << bit_index)) != 0
      end

      def self.count_bits(bitmap, max_bits)
        count = 0
        max_bits.times do |i|
          count += 1 if bit_set?(bitmap, i)
        end
        count
      end
    end
  end
end
