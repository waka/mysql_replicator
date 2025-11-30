# frozen_string_literal: true

require 'json'

module MysqlReplicator
  module Binlogs
    class JsonParser
      JSONB_TYPE_SMALL_OBJECT = 0x00
      JSONB_TYPE_LARGE_OBJECT = 0x01
      JSONB_TYPE_SMALL_ARRAY  = 0x02
      JSONB_TYPE_LARGE_ARRAY  = 0x03
      JSONB_TYPE_LITERAL      = 0x04
      JSONB_TYPE_INT16        = 0x05
      JSONB_TYPE_UINT16       = 0x06
      JSONB_TYPE_INT32        = 0x07
      JSONB_TYPE_UINT32       = 0x08
      JSONB_TYPE_INT64        = 0x09
      JSONB_TYPE_UINT64       = 0x0A
      JSONB_TYPE_DOUBLE       = 0x0B
      JSONB_TYPE_STRING       = 0x0C
      JSONB_TYPE_OPAQUE       = 0x0F

      JSONB_NULL  = 0x00
      JSONB_TRUE  = 0x01
      JSONB_FALSE = 0x02

      def self.parse(payload)
        return nil if payload.nil? || payload.empty?

        data = payload.dup.force_encoding(Encoding::BINARY)

        type = data[0].unpack('C')[0]
        parse_value(type, data, 1)
      end

      def self.parse_value(type, data, pos)
        case type
        when JSONB_TYPE_SMALL_OBJECT
          parse_object(data, pos, small: true)
        when JSONB_TYPE_LARGE_OBJECT
          parse_object(data, pos, small: false)
        when JSONB_TYPE_SMALL_ARRAY
          parse_array(data, pos, small: true)
        when JSONB_TYPE_LARGE_ARRAY
          parse_array(data, pos, small: false)
        when JSONB_TYPE_LITERAL
          parse_literal(data[pos].unpack('C')[0])
        when JSONB_TYPE_INT16
          data[pos, 2].unpack('s<')[0]
        when JSONB_TYPE_UINT16
          data[pos, 2].unpack('v')[0]
        when JSONB_TYPE_INT32
          data[pos, 4].unpack('l<')[0]
        when JSONB_TYPE_UINT32
          data[pos, 4].unpack('V')[0]
        when JSONB_TYPE_INT64
          data[pos, 8].unpack('q<')[0]
        when JSONB_TYPE_UINT64
          data[pos, 8].unpack('Q<')[0]
        when JSONB_TYPE_DOUBLE
          data[pos, 8].unpack('E')[0]
        when JSONB_TYPE_STRING
          parse_string(data, pos)
        when JSONB_TYPE_OPAQUE
          raise "OPAQUE type is not supported (type code: 0x#{data[pos].unpack('C')[0].to_s(16)})"
        else
          raise "Unknown JSON type: 0x#{type.to_s(16)} at position #{pos}"
        end
      end

      def self.parse_value_at_offset(type, data, offset, base_offset)
        abs_pos = base_offset + 1 + offset

        case type
        when JSONB_TYPE_SMALL_OBJECT
          parse_object(data, abs_pos, small: true)
        when JSONB_TYPE_LARGE_OBJECT
          parse_object(data, abs_pos, small: false)
        when JSONB_TYPE_SMALL_ARRAY
          parse_array(data, abs_pos, small: true)
        when JSONB_TYPE_LARGE_ARRAY
          parse_array(data, abs_pos, small: false)
        when JSONB_TYPE_STRING
          parse_string(data, abs_pos)
        when JSONB_TYPE_INT64
          data[abs_pos, 8].unpack('q<')[0]
        when JSONB_TYPE_UINT64
          data[abs_pos, 8].unpack('Q<')[0]
        when JSONB_TYPE_DOUBLE
          data[abs_pos, 8].unpack('E')[0]
        when JSONB_TYPE_OPAQUE
          raise "OPAQUE type is not supported (type code: 0x#{data[abs_pos].unpack('C')[0].to_s(16)})"
        else
          raise "Unexpected type at offset: 0x#{type.to_s(16)}"
        end
      end

      # SMALL: under 65535 elements, and 2byte offsets
      # LARGE: 65535 elements or more, and 4byte offsets
      def self.parse_object(data, pos, small:)
        offset_size = small ? 2 : 4

        # base offset of this object
        base_offset = pos - 1

        # Read header
        # element count is json key count
        element_count = small ? data[pos, 2].unpack('v')[0] : data[pos, 4].unpack('V')[0]
        pos += offset_size
        _byte_size = small ? data[pos, 2].unpack('v')[0] : data[pos, 4].unpack('V')[0]
        pos += offset_size

        # Read key entries
        key_entries = []
        element_count.times do
          key_offset = small ? data[pos, 2].unpack('v')[0] : data[pos, 4].unpack('V')[0]
          pos += offset_size
          key_length = data[pos, 2].unpack('v')[0]
          pos += 2
          key_entries << { offset: key_offset, length: key_length }
        end

        # Read value entries
        value_entries = []
        element_count.times do
          value_type = data[pos].unpack('C')[0]
          pos += 1

          if inlined_type?(value_type, small)
            # Small values ​​(LITERAL, INT16, etc.) are embedded directly
            inline_value = read_inlined_value(data, pos, value_type)
            pos += offset_size
            value_entries << { type: value_type, inline: true, value: inline_value }
          else
            # Large values ​​are stored as offsets
            value_offset = small ? data[pos, 2].unpack('v')[0] : data[pos, 4].unpack('V')[0]
            pos += offset_size
            value_entries << { type: value_type, inline: false, offset: value_offset }
          end
        end

        # Get real key string
        keys = key_entries.map do |entry|
          abs_pos = base_offset + 1 + entry[:offset]
          data[abs_pos, entry[:length]].force_encoding(Encoding::UTF_8)
        end

        # Get real value
        values = value_entries.map do |entry|
          if entry[:inline]
            entry[:value]
          else
            parse_value_at_offset(entry[:type], data, entry[:offset], base_offset)
          end
        end

        # Return key-value hash
        keys.zip(values).to_h
      end

      def self.parse_array(data, pos, small:)
        offset_size = small ? 2 : 4

        # base offset of this object
        base_offset = pos - 1

        # Read header
        # element count is json key count
        element_count = small ? data[pos, 2].unpack('v')[0] : data[pos, 4].unpack('V')[0]
        pos += offset_size
        _byte_size = small ? data[pos, 2].unpack('v')[0] : data[pos, 4].unpack('V')[0]
        pos += offset_size

        # Read value entries
        value_entries = []
        element_count.times do
          value_type = data[pos].unpack('C')[0]
          pos += 1

          if inlined_type?(value_type, small)
            # Small values ​​(LITERAL, INT16, etc.) are embedded directly
            inline_value = read_inlined_value(data, pos, value_type)
            pos += offset_size
            value_entries << { type: value_type, inline: true, value: inline_value }
          else
            # Large values ​​are stored as offsets
            value_offset = small ? data[pos, 2].unpack('v')[0] : data[pos, 4].unpack('V')[0]
            pos += offset_size
            value_entries << { type: value_type, inline: false, offset: value_offset }
          end
        end

        # Return real value array
        value_entries.map do |entry|
          if entry[:inline]
            entry[:value]
          else
            parse_value_at_offset(entry[:type], data, entry[:offset], base_offset)
          end
        end
      end

      def self.parse_literal(literal_type)
        case literal_type
        when JSONB_NULL  then nil
        when JSONB_TRUE  then true
        when JSONB_FALSE then false
        else
          raise "Unknown literal type: #{literal_type}"
        end
      end

      def self.parse_string(data, pos)
        length, bytes_read = read_variable_length(data, pos)
        data[pos + bytes_read, length].force_encoding(Encoding::UTF_8)
      end

      def self.inlined_type?(type, small)
        case type
        when JSONB_TYPE_LITERAL, JSONB_TYPE_INT16, JSONB_TYPE_UINT16
          true
        when JSONB_TYPE_INT32, JSONB_TYPE_UINT32
          !small
        else
          false
        end
      end

      def self.read_inlined_value(data, pos, type)
        case type
        when JSONB_TYPE_LITERAL
          parse_literal(data[pos].unpack('C')[0])
        when JSONB_TYPE_INT16
          data[pos, 2].unpack('s<')[0]
        when JSONB_TYPE_UINT16
          data[pos, 2].unpack('v')[0]
        when JSONB_TYPE_INT32
          data[pos, 4].unpack('l<')[0]
        when JSONB_TYPE_UINT32
          data[pos, 4].unpack('V')[0]
        end
      end

      def self.read_variable_length(data, pos)
        length = 0
        shift = 0
        bytes_read = 0

        loop do
          byte = data[pos + bytes_read].unpack('C')[0]
          bytes_read += 1
          length |= (byte & 0x7F) << shift
          break if (byte & 0x80).zero?

          shift += 7
        end

        [length, bytes_read]
      end
    end
  end
end
