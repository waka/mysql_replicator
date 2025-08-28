# frozen_string_literal: true

module MysqlReplicator
  module Binlog
    class ColumnParser
      def self.parse_value(data, column_type)
        return ['[insufficient data]', 0] if data.empty?

        case column_type
        # Integer types
        when 'tinyint'
          [data[0].unpack('c')[0], 1] # signed byte
        when 'smallint'
          [data[0, 2].unpack('s<')[0], 2] # signed 16-bit little endian
        when 'mediumint'
          # MySQL MEDIUMINT is 3 bytes, sign-extended to 4 bytes
          bytes = data[0, 3] + "\x00"
          value = bytes.unpack('l<')[0]
          # Handle sign extension for 3-byte values
          value -= 0x1000000 if value > 0x7FFFFF
          [value, 3]
        when 'int'
          [data[0, 4].unpack('l<')[0], 4] # signed 32-bit little endian
        when 'bigint'
          [data[0, 8].unpack('q<')[0], 8] # signed 64-bit little endian

        # Floating point types
        when 'float'
          [data[0, 4].unpack('e')[0], 4]  # 32-bit float little endian
        when 'double'
          [data[0, 8].unpack('E')[0], 8]  # 64-bit double little endian

        # Decimal types
        when 'decimal'
          parse_decimal_value(data)

        # String types
        when 'char', 'varchar', 'text', 'tinytext', 'mediumtext', 'longtext'
          parse_string_value(data)
        when 'binary', 'varbinary'
          parse_binary_value(data)

        # Blob types
        when 'tinyblob', 'blob', 'mediumblob', 'longblob'
          parse_blob_value(data)

        # Date and time types
        when 'date'
          parse_date_value(data)
        when 'time'
          parse_time_value(data)
        when 'datetime'
          parse_datetime_value(data)
        when 'timestamp'
          parse_timestamp_value(data)

        # JSON type
        when 'json'
          parse_json_value(data)

        # Enum
        when 'enum'
          parse_enum_value(data)

        # Spatial types
        when 'geometry', 'point', 'polygon', 'multipoint', 'multipolygon', 'geometrycollection'
          parse_geometry_value(data)

        # Unknown or unsupported types
        else
          # For unknown types, show hex data
          bytes_to_show = [data.length, 8].min
          ["UNKNOWN #{data[0, bytes_to_show].unpack('H*')[0]}", bytes_to_show]
        end
      end

      def self.parse_decimal_value(data)
        # Simplified decimal parsing - actual implementation is complex
        length, length_bytes = read_packed_integer(data)
        total_bytes = length_bytes + length

        decimal_data = data[length_bytes, length]
        [decimal_data.unpack('H*')[0], total_bytes]
      end

      def self.parse_string_value(data)
        # Length-encoded string
        length, length_bytes = read_packed_integer(data)
        total_bytes = length_bytes + length

        string_data = data[length_bytes, length]
        [string_data.force_encoding('UTF-8').scrub, total_bytes]
      end

      def self.parse_binary_value(data)
        # Length-encoded string
        length, length_bytes = read_packed_integer(data)
        total_bytes = length_bytes + length

        binary_data = data[length_bytes, length]
        [binary_data.unpack('H*')[0], total_bytes]
      end

      def self.parse_blob_value(data)
        # Length-encoded blob
        length, length_bytes = read_packed_integer(data)
        total_bytes = length_bytes + length

        blob_data = data[length_bytes, length]
        [blob_data.unpack('H*')[0], total_bytes]
      end

      def self.parse_date_value(data)
        # MySQL date format: 3 bytes
        date_int = data[0, 3].unpack('V')[0] & 0xFFFFFF

        if date_int == 0
          ['0000-00-00', 3]
        else
          day = date_int % 32
          month = (date_int >> 5) % 16
          year = date_int >> 9
          ["#{year}-#{month.to_s.rjust(2, '0')}-#{day.to_s.rjust(2, '0')}", 3]
        end
      end

      def self.parse_time_value(data)
        # MySQL time format: 3 bytes
        time_int = data[0, 3].unpack('V')[0] & 0xFFFFFF

        if time_int == 0
          ['00:00:00', 3]
        else
          second = time_int % 60
          minute = (time_int / 60) % 60
          hour = time_int / 3600
          ["#{hour.to_s.rjust(2, '0')}:#{minute.to_s.rjust(2, '0')}:#{second.to_s.rjust(2, '0')}", 3]
        end
      end

      def self.parse_datetime_value(data)
        datetime_int = data[0, 8].unpack('Q<')[0]

        # MySQL DATETIME format: YYYYMMDDHHMMSS
        if datetime_int == 0
          ['0000-00-00 00:00:00', 8]
        else
          second = datetime_int % 100
          datetime_int /= 100
          minute = datetime_int % 100
          datetime_int /= 100
          hour = datetime_int % 100
          datetime_int /= 100
          day = datetime_int % 100
          datetime_int /= 100
          month = datetime_int % 100
          datetime_int /= 100
          year = datetime_int

          ["#{year}-#{month.to_s.rjust(2, '0')}-#{day.to_s.rjust(2, '0')} #{hour.to_s.rjust(2, '0')}:#{minute.to_s.rjust(2, '0')}:#{second.to_s.rjust(2, '0')}", 8]
        end
      end

      def self.parse_timestamp_value(data)
        timestamp = data[0, 4].unpack('V')[0]
        [Time.at(timestamp).strftime('%Y-%m-%d %H:%M:%S'), 4]
      end

      def self.parse_json_value(data)
        # JSON is stored as length-encoded string
        length, length_bytes = read_packed_integer(data)
        total_bytes = length_bytes + length

        json_data = data[length_bytes, length]
        begin
          # Try to parse as JSON for pretty display
          require 'json'
          parsed = JSON.parse(json_data.force_encoding('UTF-8'))
          [parsed, total_bytes]
        rescue
          # If parsing fails, return as string
          [json_data.force_encoding('UTF-8').scrub, total_bytes]
        end
      end

      def self.parse_enum_value(data)
        # ENUM is stored as integer index
        enum_index = data[0].unpack('C')[0]
        [enum_index, 1]
      end

      def self.parse_geometry_value(data)
        length, length_bytes = read_packed_integer(data)
        total_bytes = length_bytes + length

        geometry_data = data[length_bytes, length]
        [geometry_data.unpack('H*')[0], total_bytes]
      end

      def self.read_packed_integer(data)
        return [0, 0] if data.empty?

        first_byte = data[0].unpack('C')[0]

        case first_byte
        when 0..250
          [first_byte, 1]
        when 252
          return [0, 1] if data.length < 3

          [data[1, 2].unpack('v')[0], 3]
        when 253
          return [0, 1] if data.length < 4

          [data[1, 3].unpack('V')[0] & 0xFFFFFF, 4]
        when 254
          return [0, 1] if data.length < 9

          [data[1, 8].unpack('Q<')[0], 9]
        else
          [0, 1]
        end
      end
    end
  end
end
