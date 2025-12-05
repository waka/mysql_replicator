# frozen_string_literal: true
# rbs_inline: enabled

module MysqlReplicator
  class StringIOUtil
    # @rbs io: StringIO
    # @rbs return: Integer
    def self.read_packed_integer(io)
      first = read_uint8(io)

      case first
      when 0..250
        first
      when 252
        read_uint16(io)
      when 253
        read_uint24(io)
      when 254
        read_uint64(io)
      else
        raise "Invalid packed integer: #{first}"
      end
    end

    # @rbs io: StringIO
    # @rbs return: Integer
    def self.read_int8(io)
      io.read(1).unpack1('c')
    end

    # @rbs io: StringIO
    # @rbs return: Integer
    def self.read_uint8(io)
      io.read(1).unpack1('C')
    end

    # @rbs io: StringIO
    # @rbs return: Integer
    def self.read_int16(io)
      io.read(2).unpack1('s<')
    end

    # @rbs io: StringIO
    # @rbs return: Integer
    def self.read_uint16(io)
      io.read(2).unpack1('v')
    end

    # @rbs io: StringIO
    # @rbs return: Integer
    def self.read_int24(io)
      bytes = io.read(3).unpack('C3')
      value = bytes[0] | (bytes[1] << 8) | (bytes[2] << 16)
      value >= 0x800000 ? value - 0x1000000 : value
    end

    # @rbs io: StringIO
    # @rbs return: Integer
    def self.read_uint24(io)
      bytes = io.read(3).unpack('C3')
      bytes[0] | (bytes[1] << 8) | (bytes[2] << 16)
    end

    # @rbs io: StringIO
    # @rbs return: Integer
    def self.read_int32(io)
      io.read(4).unpack1('l<')
    end

    # @rbs io: StringIO
    # @rbs return: Integer
    def self.read_uint32(io)
      io.read(4).unpack1('V')
    end

    # @rbs io: StringIO
    # @rbs return: Integer
    def self.read_int48(io)
      low = read_int32(io)
      high = read_int16(io)
      combined = low | (high << 32)
      combined >= 0x800000000000 ? combined - 0x1000000000000 : combined
    end

    # @rbs io: StringIO
    # @rbs return: Integer
    def self.read_uint48(io)
      low = read_uint32(io)
      high = read_uint16(io)
      low | (high << 32)
    end

    # @rbs io: StringIO
    # @rbs return: Integer
    def self.read_int64(io)
      io.read(8).unpack1('q<')
    end

    # @rbs io: StringIO
    # @rbs return: Integer
    def self.read_uint64(io)
      io.read(8).unpack1('Q<')
    end
  end
end
