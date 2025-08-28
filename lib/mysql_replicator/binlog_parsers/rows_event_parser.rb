# frozen_string_literal: true

module MysqlReplicator
  module BinlogParsers
    class RowsEventParser
      def self.parse(payload, connection, checksum_enabled, table_map)
        {}
      end

      def self.column_present?(bitmap, column_index)
        byte_index = column_index / 8
        bit_index = column_index % 8
        return false if byte_index >= bitmap.length

        (bitmap[byte_index].unpack('C')[0] & (1 << bit_index)) != 0
      end

      def self.column_null?(null_bitmap, column_index)
        byte_index = column_index / 8
        bit_index = column_index % 8
        return false if byte_index >= null_bitmap.length

        (null_bitmap[byte_index].unpack('C')[0] & (1 << bit_index)) != 0
      end
    end
  end
end
