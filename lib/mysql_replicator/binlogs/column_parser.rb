# frozen_string_literal: true

require 'bigdecimal'

module MysqlReplicator
  module Binlogs
    class ColumnParser
      def self.parse(payload, column_def)
        type_code = MysqlReplicator::Binlogs::FieldTypes.code_for(column_def[:data_type])

        case type_code
        when MysqlReplicator::Binlogs::FieldTypes::TINY_INT
          parse_tinyint(payload, column_def)
        when MysqlReplicator::Binlogs::FieldTypes::SMALL_INT
          parse_smallint(payload, column_def)
        when MysqlReplicator::Binlogs::FieldTypes::MEDIUM_INT
          parse_mediumint(payload, column_def)
        when MysqlReplicator::Binlogs::FieldTypes::INT
          parse_int(payload, column_def)
        when MysqlReplicator::Binlogs::FieldTypes::BIG_INT
          parse_bigint(payload, column_def)
        when MysqlReplicator::Binlogs::FieldTypes::FLOAT
          parse_float(payload, column_def)
        when MysqlReplicator::Binlogs::FieldTypes::DOUBLE
          parse_double(payload, column_def)
        when MysqlReplicator::Binlogs::FieldTypes::DECIMAL
          parse_decimal(payload, column_def)
        when MysqlReplicator::Binlogs::FieldTypes::DATETIME
          parse_datetime(payload, column_def)
        when MysqlReplicator::Binlogs::FieldTypes::DATE
          parse_date(payload, column_def)
        when MysqlReplicator::Binlogs::FieldTypes::TIME
          parse_time(payload, column_def)
        when MysqlReplicator::Binlogs::FieldTypes::TIMESTAMP
          parse_timestamp(payload, column_def)
        when MysqlReplicator::Binlogs::FieldTypes::CHAR
          parse_char(payload, column_def)
        when MysqlReplicator::Binlogs::FieldTypes::VARCHAR
          parse_varchar(payload, column_def)
        when MysqlReplicator::Binlogs::FieldTypes::TINY_TEXT
          parse_tinytext(payload, column_def)
        when MysqlReplicator::Binlogs::FieldTypes::TEXT
          parse_text(payload, column_def)
        when MysqlReplicator::Binlogs::FieldTypes::MEDIUM_TEXT
          parse_mediumtext(payload, column_def)
        when MysqlReplicator::Binlogs::FieldTypes::LONG_TEXT
          parse_longtext(payload, column_def)
        when MysqlReplicator::Binlogs::FieldTypes::TINY_BLOB
          parse_tinyblob(payload, column_def)
        when MysqlReplicator::Binlogs::FieldTypes::BLOB
          parse_blob(payload, column_def)
        when MysqlReplicator::Binlogs::FieldTypes::MEDIUM_BLOB
          parse_mediumblob(payload, column_def)
        when MysqlReplicator::Binlogs::FieldTypes::LONG_BLOB
          parse_longblob(payload, column_def)
        when MysqlReplicator::Binlogs::FieldTypes::BINARY
          parse_binary(payload, column_def)
        when MysqlReplicator::Binlogs::FieldTypes::VAR_BINARY
          parse_varbinary(payload, column_def)
        when MysqlReplicator::Binlogs::FieldTypes::JSON
          parse_json(payload, column_def)
        when MysqlReplicator::Binlogs::FieldTypes::ENUM
          parse_enum(payload, column_def)
        else
          raise MysqlReplicator::Error, "Unsupported type: #{type_code}"
        end
      end

      def self.parse_tinyint(payload, _column_def)
        value = payload[0, 1].unpack('C')[0]
        { value: value, byte_consumed: 1 }
      end

      def self.parse_smallint(payload, _column_def)
        value = payload[0, 2].unpack('S<')[0]
        { value: value, byte_consumed: 2 }
      end

      def self.parse_mediumint(payload, _column_def)
        bytes = payload[0, 3].unpack('C*')
        value = bytes[0] | (bytes[1] << 8) | (bytes[2] << 16)
        { value: value, byte_consumed: 3 }
      end

      def self.parse_int(payload, _column_def)
        value = payload[0, 4].unpack('V')[0]
        { value: value, byte_consumed: 4 }
      end

      def self.parse_bigint(payload, _column_def)
        value = payload[0, 8].unpack('Q<')[0]
        { value: value, byte_consumed: 8 }
      end

      def self.parse_float(payload, _column_def)
        value = payload[0, 4].unpack('e')[0]
        { value: value, byte_consumed: 4 }
      end

      def self.parse_double(payload, _column_def)
        value = payload[0, 8].unpack('E')[0]
        { value: value, byte_consumed: 8 }
      end

      # This is sensitive...
      def self.parse_decimal(payload, column_def)
        precision = column_def[:numeric_precision] || 10
        scale = column_def[:numeric_scale] || 0

        decimal_size = calculate_decimal_size(precision, scale)
        data = payload[0, decimal_size]

        first_byte = data[0].unpack('C')[0]
        is_positive = (first_byte & 0x80) != 0
        if is_positive
          # Strip the sign bit from the first byte, if positive number
          adjusted_data = data.dup
          adjusted_data[0] = [first_byte & 0x7F].pack('C')
        else
          # Restore the original value from complement of 2, if negative number
          adjusted_data = data.bytes.map { |b| 255 - b }.pack('C*')
          first_adjusted = adjusted_data[0].unpack('C')[0]
          adjusted_data[0] = [first_adjusted | 0x80].pack('C')
        end

        int_digits = precision - scale
        int_part = extract_decimal_part(adjusted_data, 0, int_digits)
        fraction_part = extract_decimal_part(adjusted_data, calculate_decimal_integer_bytes(int_digits), scale)

        # Restructure as BigDecimal
        decimal_str = "#{'-' unless is_positive}#{int_part}"
        if scale > 0
          fraction_str = fraction_part.to_s.rjust(scale, 0)
          decimal_str += ".#{fraction_str}"
        end

        value = BigDecimal(decimal_str)
        { value: value, byte_consumed: decimal_size }
      end

      def self.parse_datetime(payload, _column_def)
        datetime_int = payload[0, 8].unpack('Q<')[0]

        second = datetime_int % 100
        datetime_int /= 100
        minute = datetime_int % 100
        datetime_int /= 100
        hour = datetime_int % 100
        datetime_int /= 100
        day = datetime_int % 100
        datetime_int /= 100
        month = datetime_int % 100
        year = datetime_int / 100

        value = Time.new(year, month, day, hour, minute, second)
        { value: value, byte_consumed: 8 }
      end

      def self.parse_date(payload, _column_def)
        date_int = payload[0, 3].unpack('V')[0] & 0xFFFFF

        day = date_int % 32
        date_int /= 32
        month = date_int % 16
        year = date_int / 16

        value = Date.new(year, month, day)
        { value: value, byte_consumed: 3 }
      end

      def self.parse_time(payload, _column_def)
        time_int = payload[0, 3].unpack('V')[0] & 0xFFFFFF

        is_negative = (time_int & 0x800000) != 0
        time_int = 0x1000000 - time_int if is_negative

        second = time_int % 60
        time_int /= 60
        minute = time_int % 60
        hour = time_int / 60

        value = format('%s%02d:%02d:%02d', is_negative ? '-' : '', hour, minute, second)
        { value: value, byte_consumed: 3 }
      end

      def self.parse_timestamp(payload, _column_def)
        timestamp = payload[0, 4].unpack('N')[0] # timestamp is Big-Engian

        value = Time.at(timestamp)
        { value: value, byte_consumed: 4 }
      end

      def self.parse_varchar(payload, column_def)
        byte_length = case column_def[:character_set_name]
                      when 'utf8mb4' then 4
                      when 'utf8' then 3
                      else 1
                      end
        max_length = (column_def[:character_maximum_length] || 255) * byte_length

        if max_length <= 255
          # Prefix for 1 byte length
          length = payload[0, 1].unpack('C')[0]
          str_start = 1
          byte_consumed = 1 + length
        else
          # Prefix for 2 byte length (little-endian)
          length = payload[0, 2].unpack('v')[0]
          str_start = 2
          byte_consumed = 2 + length
        end

        value = payload[str_start, length].force_encoding('utf-8')
        { value: value, byte_consumed: byte_consumed }
      end

      def self.parse_char(payload, column_def)
        length = column_def[:character_maximum_length] || 1

        value = payload[0, length].gsub(/\x00+$/, '').force_encoding('utf-8').rstrip
        { value: value, byte_consumed: byte_consumed }
      end

      def self.parse_tinytext(payload, _col_def)
        length = payload[0, 1].unpack('C')[0]

        value = payload[1, length].force_encoding('UTF-8')
        { value: value, byte_consumed: 1 + length }
      end

      def self.parse_text(payload, _column_def)
        length = payload[0, 2].unpack('v')[0]

        value = payload[2, length].force_encoding('UTF-8')
        { value: value, byte_consumed: 2 + length }
      end

      def self.parse_mediumtext(payload, _column_def)
        bytes = payload[0, 3].unpack('C*')
        length = bytes[0] | (bytes[1] << 8) | (bytes[2] << 16)

        value = payload[3, length].force_encoding('UTF-8')
        { value: value, byte_consumed: 3 + length }
      end

      def self.parse_longtext(payload, _column_def)
        length = payload[0, 4].unpack('V')[0]

        value = payload[4, length].force_encoding('UTF-8')
        { value: value, byte_consumed: 4 + length }
      end

      def self.parse_tinyblob(payload, _col_def)
        length = payload[0, 1].unpack('C')[0]

        value = payload[1, length]
        { value: value, byte_consumed: 1 + length }
      end

      def self.parse_blob(payload, _column_def)
        length = payload[0, 2].unpack('v')[0]

        value = payload[2, length]
        { value: value, byte_consumed: 2 + length }
      end

      def self.parse_mediumblob(payload, _column_def)
        bytes = payload[0, 3].unpack('C*')
        length = bytes[0] | (bytes[1] << 8) | (bytes[2] << 16)

        value = payload[3, length]
        { value: value, byte_consumed: 3 + length }
      end

      def self.parse_longblob(payload, _column_def)
        length = payload[0, 4].unpack('V')[0]

        value = payload[4, length]
        { value: value, byte_consumed: 4 + length }
      end

      def self.parse_varbinary(payload, column_def)
        max_length = column_def[:character_maximum_length] || 255

        if max_length <= 255
          length = payload[0, 1].unpack('C')[0]
          str_start = 1
          byte_consumed = 1 + length
        else
          length = payload[0, 2].unpack('v')[0]
          str_start = 2
          byte_consumed = 2 + length
        end

        value = payload[str_start, length].force_encoding('utf-8')
        { value: value, byte_consumed: byte_consumed }
      end

      def self.parse_binary(payload, column_def)
        length = column_def[:character_maximum_length] || 1

        value = payload[0, length].force_encoding('utf-8').rstrip
        { value: value, byte_consumed: byte_consumed }
      end

      def self.parse_json(payload, column_def)
        result = parse_blob(payload, column_def)
        json = JSON.parse(result[:value])
        { value: json, byte_consumed: result[:byte_consumed] }
      end

      def self.parse_enum(payload, _column_def)
        value = payload[0, 1].unpack('C')[0]
        { value: value, byte_consumed: 1 }
      end

      # MySQL DECIMAL format
      # - 4 bytes as every 9 digits
      # - Add bytes depending on the remaining digits
      def self.calculate_decimal_size(precision, scale)
        int_digits = precision - scale
        int_words = int_digits / 9
        int_remaining = int_digits % 9

        fraction_digits = scale
        fraction_words = fraction_digits / 9
        fraction_remaining = fraction_digits % 9

        int_bytes = (int_words * 4) + calculate_decimal_remaining_bytes(int_remaining)
        fraction_bytes = (fraction_words * 4) + calculate_decimal_remaining_bytes(fraction_remaining)
        int_bytes + fraction_bytes
      end

      # Calculate bytes corresponding to remaining digits
      def self.calculate_decimal_remaining_bytes(remaining)
        case remaining
        when 0 then 0
        when 1, 2 then 1
        when 3, 4 then 2
        when 5, 6 then 3
        when 7, 8, 9 then 4
        else 0 # rubocop:disable Lint/DuplicateBranch
        end
      end

      # Calculate bytes at integer part of decimal
      def self.calculate_decimal_integer_bytes(int_digits)
        words = int_digits / 9
        remaining = int_digits % 9
        (words * 4) + calculate_decimal_remaining_bytes(remaining)
      end

      # Extract integer or fractional part of a decimal
      def self.extract_decimal_part(payload, offset, digits)
        words = digits / 9
        remaining = digits % 9

        value = 0

        words.times do
          v = payload[offset, 4].unpack('N')[0] # Big-Endian
          value = (value * 1_000_000_000) + v
          offset += 4
        end

        # Process remaining digits
        if remaining > 0
          remaining_bytes = calculate_decimal_remaining_bytes(remaining)
          remaining_data = payload[offset, remaining_bytes].ljust(4, "\x00")
          remaining_value = remaining_data.unpack('N')[0]

          # Adjust to significant digits
          divisor = 10**(9 - remaining)
          remaining_value /= divisor

          value = (value * (10**remaining)) + remaining_value
        end

        value
      end
    end
  end
end
