# frozen_string_literal: true

require 'bigdecimal'
require 'json'

module MysqlReplicator
  module Binlogs
    class ColumnParser
      def self.parse(io, column_def)
        type_code = MysqlReplicator::Binlogs::FieldTypes.code_for(column_def[:data_type])

        case type_code
        when MysqlReplicator::Binlogs::FieldTypes::TINY_INT
          parse_tinyint(io)
        when MysqlReplicator::Binlogs::FieldTypes::SMALL_INT
          parse_smallint(io)
        when MysqlReplicator::Binlogs::FieldTypes::MEDIUM_INT
          parse_mediumint(io)
        when MysqlReplicator::Binlogs::FieldTypes::INT
          parse_int(io)
        when MysqlReplicator::Binlogs::FieldTypes::BIG_INT
          parse_bigint(io)
        when MysqlReplicator::Binlogs::FieldTypes::FLOAT
          parse_float(io)
        when MysqlReplicator::Binlogs::FieldTypes::DOUBLE
          parse_double(io)
        when MysqlReplicator::Binlogs::FieldTypes::DECIMAL
          parse_decimal(io, column_def)
        when MysqlReplicator::Binlogs::FieldTypes::DATETIME
          parse_datetime(io)
        when MysqlReplicator::Binlogs::FieldTypes::DATE
          parse_date(io)
        when MysqlReplicator::Binlogs::FieldTypes::TIME
          parse_time(io)
        when MysqlReplicator::Binlogs::FieldTypes::TIMESTAMP
          parse_timestamp(io)
        when MysqlReplicator::Binlogs::FieldTypes::CHAR
          parse_char(io, column_def)
        when MysqlReplicator::Binlogs::FieldTypes::VARCHAR
          parse_varchar(io, column_def)
        when MysqlReplicator::Binlogs::FieldTypes::TINY_TEXT
          parse_tinytext(io, column_def)
        when MysqlReplicator::Binlogs::FieldTypes::TEXT
          parse_text(io, column_def)
        when MysqlReplicator::Binlogs::FieldTypes::MEDIUM_TEXT
          parse_mediumtext(io, column_def)
        when MysqlReplicator::Binlogs::FieldTypes::LONG_TEXT
          parse_longtext(io, column_def)
        when MysqlReplicator::Binlogs::FieldTypes::TINY_BLOB
          parse_tinyblob(io)
        when MysqlReplicator::Binlogs::FieldTypes::BLOB
          parse_blob(io)
        when MysqlReplicator::Binlogs::FieldTypes::MEDIUM_BLOB
          parse_mediumblob(io)
        when MysqlReplicator::Binlogs::FieldTypes::LONG_BLOB
          parse_longblob(io)
        when MysqlReplicator::Binlogs::FieldTypes::BINARY
          parse_binary(io, column_def)
        when MysqlReplicator::Binlogs::FieldTypes::VAR_BINARY
          parse_varbinary(io, column_def)
        when MysqlReplicator::Binlogs::FieldTypes::JSON
          parse_json(io)
        when MysqlReplicator::Binlogs::FieldTypes::ENUM
          parse_enum(io, column_def)
        else
          raise MysqlReplicator::Error, "Unsupported type: #{type_code}"
        end
      end

      def self.parse_tinyint(io)
        MysqlReplicator::StringIOUtil.read_int8(io)
      end

      def self.parse_smallint(io)
        MysqlReplicator::StringIOUtil.read_int16(io)
      end

      def self.parse_mediumint(io)
        MysqlReplicator::StringIOUtil.read_int24(io)
      end

      def self.parse_int(io)
        MysqlReplicator::StringIOUtil.read_int32(io)
      end

      def self.parse_bigint(io)
        MysqlReplicator::StringIOUtil.read_int64(io)
      end

      def self.parse_float(io)
        io.read(4).unpack('e')[0]
      end

      def self.parse_double(io)
        io.read(8).unpack('E')[0]
      end

      # This is sensitive...
      def self.parse_decimal(io, column_def)
        precision = column_def[:numeric_precision] || 10
        scale = column_def[:numeric_scale] || 0

        # Decimal format is integer and fractional parts
        intg = precision - scale
        intg_bytes = decimal_storage_bytes(intg)
        frac_bytes = decimal_storage_bytes(scale)
        total_bytes = intg_bytes + frac_bytes

        data = io.read(total_bytes).unpack('C*')

        # top level bit is sign bit (1 = positive, 0 = negative)
        negative = (data[0] & 0x80) == 0
        # inversion of sign bit
        data[0] ^= 0x80
        data = data.map { |b| b ^ 0xFF } if negative

        # parse integer part
        intg_part = parse_decimal_digits(data[0, intg_bytes], intg)
        # parse fractional part
        frac_part = parse_decimal_digits(data[intg_bytes, frac_bytes], scale)

        result = "#{intg_part}.#{frac_part.to_s.rjust(scale, '0')}"
        result = "-#{result}" if negative

        BigDecimal(result)
      end

      def self.parse_datetime(io)
        # 5bytes if fractional seconds precision is 0
        # format: 1bit sign + 17bits year*13month+month + 5bits day + 5bits hour + 6bits minute + 6bits second
        data = io.read(5).unpack('C5')
        value = (data[0] << 32) | (data[1] << 24) | (data[2] << 16) | (data[3] << 8) | data[4]

        # top level bit is sign bit
        value ^= 0x8000000000 # inversion of sign bit

        second = value & 0x3F
        value >>= 6
        minute = value & 0x3F
        value >>= 6
        hour = value & 0x1F
        value >>= 5
        day = value & 0x1F
        value >>= 5
        year_month = value & 0x1FFFF
        year = year_month / 13
        month = year_month % 13

        "#{year}-#{format('%02d', month)}-#{format('%02d', day)} " \
          "#{format('%02d', hour)}:#{format('%02d', minute)}:#{format('%02d', second)}"
      end

      def self.parse_date(io)
        # 3bytes: YYYY*16*32 + MM*32 + DD
        value = MysqlReplicator::StringIOUtil.read_uint24(io)

        day = value & 0x1F
        month = (value >> 5) & 0x0F
        year = value >> 9

        "#{year}-#{format('%02d', month)}-#{format('%02d', day)}"
      end

      def self.parse_time(io)
        # 3bytes if fractional seconds precision is 0
        # format: 1bit sign + 1bit unused + 10bits hour + 6bits minute + 6bits second
        data = io.read(3).unpack('C3')
        value = (data[0] << 16) | (data[1] << 8) | data[2]

        negative = (value & 0x800000) == 0
        value &= 0x7FFFFF

        hour = (value >> 12) & 0x3FF
        minute = (value >> 6) & 0x3F
        second = value & 0x3F

        if negative
          "-#{hour}:#{minute.to_s.rjust(2, '0')}:#{second.to_s.rjust(2, '0')}"
        else
          "#{hour}:#{minute.to_s.rjust(2, '0')}:#{second.to_s.rjust(2, '0')}"
        end
      end

      def self.parse_timestamp(io)
        # 4bytes if fractional seconds precision is 0
        # Unix Timestamp is Big-Engian
        io.read(4).unpack('N')[0]
      end

      def self.parse_varchar(io, column_def)
        max_length = column_def[:character_maximum_length] || 255
        charset = column_def[:character_set_name]

        # Determine length prefix size
        bytes_per_char = case charset
                         when 'utf8mb4' then 4
                         when 'utf8', 'utf8mb3' then 3
                         else 1 # binary, latin1 and others
                         end
        max_bytes = max_length * bytes_per_char

        length = if max_bytes > 255
                   MysqlReplicator::StringIOUtil.read_uint16(io)
                 else
                   MysqlReplicator::StringIOUtil.read_uint8(io)
                 end

        value = io.read(length)
        charset ? value.force_encoding('utf-8') : value
      end

      def self.parse_char(io, column_def)
        max_length = column_def[:character_maximum_length] || 10
        charset = column_def[:character_set_name]

        # Determine length prefix size
        bytes_per_char = case charset
                         when 'utf8mb4' then 4
                         when 'utf8', 'utf8mb3' then 3
                         else 1 # binary, latin1 and others
                         end
        max_bytes = max_length * bytes_per_char

        length = if max_bytes > 255
                   MysqlReplicator::StringIOUtil.read_uint16(io)
                 else
                   MysqlReplicator::StringIOUtil.read_uint8(io)
                 end

        value = io.read(length)
        charset ? value.force_encoding('utf-8') : value
      end

      def self.parse_tinytext(io, column_def)
        charset = column_def[:character_set_name]
        length = MysqlReplicator::StringIOUtil.read_uint8(io)

        value = io.read(length)
        charset ? value.force_encoding('utf-8') : value
      end

      def self.parse_text(io, column_def)
        charset = column_def[:character_set_name]
        length = MysqlReplicator::StringIOUtil.read_uint16(io)

        value = io.read(length)
        charset ? value.force_encoding('utf-8') : value
      end

      def self.parse_mediumtext(io, column_def)
        charset = column_def[:character_set_name]
        length = MysqlReplicator::StringIOUtil.read_uint24(io)

        value = io.read(length)
        charset ? value.force_encoding('utf-8') : value
      end

      def self.parse_longtext(io, column_def)
        charset = column_def[:character_set_name]
        length = MysqlReplicator::StringIOUtil.read_uint32(io)

        value = io.read(length)
        charset ? value.force_encoding('utf-8') : value
      end

      def self.parse_tinyblob(io)
        length = MysqlReplicator::StringIOUtil.read_uint8(io)
        io.read(length)
      end

      def self.parse_blob(io)
        length = MysqlReplicator::StringIOUtil.read_uint16(io)
        io.read(length)
      end

      def self.parse_mediumblob(io)
        length = MysqlReplicator::StringIOUtil.read_uint24(io)
        io.read(length)
      end

      def self.parse_longblob(io)
        length = MysqlReplicator::StringIOUtil.read_uint32(io)
        io.read(length)
      end

      def self.parse_varbinary(io, column_def)
        parse_varchar(io, column_def)
      end

      def self.parse_binary(io, column_def)
        parse_char(io, column_def)
      end

      def self.parse_json(io)
        length = MysqlReplicator::StringIOUtil.read_uint32(io)
        data = io.read(length)
        MysqlReplicator::Binlogs::JsonParser.parse(data)
      end

      def self.parse_enum(io, column_def)
        enum_values = column_def[:enum_values] || []
        index = if enum_values && enum_values.length > 255
                  MysqlReplicator::StringIOUtil.read_uint16(io)
                else
                  MysqlReplicator::StringIOUtil.read_uint8(io)
                end

        # Enum index starts from 1
        if index > 0 && enum_values
          enum_values[index - 1]
        else
          index
        end
      end

      def self.decimal_storage_bytes(digits)
        # Each group of 9 digits takes 4 bytes
        full_groups = digits / 9
        leftover_digits = digits % 9
        (full_groups * 4) + [0, 1, 1, 2, 2, 3, 3, 4, 4][leftover_digits]
      end

      def self.parse_decimal_digits(bytes, digits)
        return 0 if digits == 0 || bytes.nil? || bytes.empty?

        leftover_digits = digits % 9
        leftover_bytes = [0, 1, 1, 2, 2, 3, 3, 4, 4][leftover_digits]

        result = 0
        offset = 0

        # fraction part
        if leftover_digits > 0
          val = 0
          leftover_bytes.times do |i|
            val = (val << 8) | bytes[offset + i]
          end
          result = val
          offset += leftover_bytes
        end

        # 9-digit groups (4 bytes each)
        while offset < bytes.length
          val = (bytes[offset] << 24) |
                (bytes[offset + 1] << 16) |
                (bytes[offset + 2] << 8) |
                bytes[offset + 3]
          result = (result * 1_000_000_000) + val
          offset += 4
        end

        result
      end
    end
  end
end
