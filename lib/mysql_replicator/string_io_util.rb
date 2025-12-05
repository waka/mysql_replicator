# frozen_string_literal: true
# rbs_inline: enabled

module MysqlReplicator
  class StringIOUtil
    # @rbs io: StringIO
    # @rbs return: String
    def self.read_str(io, length)
      io.read(length) || ''
    end

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
      value = io.read(1)
      if value.nil?
        raise MysqlReplicator::Error, 'payload is nil'
      end

      value.unpack1('c').to_i
    end

    # @rbs io: StringIO
    # @rbs return: Integer
    def self.read_uint8(io)
      value = io.read(1)
      if value.nil?
        raise MysqlReplicator::Error, 'payload is nil'
      end

      value.unpack1('C').to_i
    end

    # @rbs io: StringIO
    # @rbs return: Integer
    def self.read_int16(io)
      value = io.read(2)
      if value.nil?
        raise MysqlReplicator::Error, 'payload is nil'
      end

      value.unpack1('s<').to_i
    end

    # @rbs io: StringIO
    # @rbs return: Integer
    def self.read_uint16(io)
      value = io.read(2)
      if value.nil?
        raise MysqlReplicator::Error, 'payload is nil'
      end

      value.unpack1('v').to_i
    end

    # @rbs io: StringIO
    # @rbs return: Integer
    def self.read_int24(io)
      payload = io.read(3)
      if payload.nil?
        raise MysqlReplicator::Error, 'payload is nil'
      end

      bytes = payload.unpack('C3').map(&:to_i)
      value = bytes[0] | (bytes[1] << 8) | (bytes[2] << 16)
      value >= 0x800000 ? value - 0x1000000 : value
    end

    # @rbs io: StringIO
    # @rbs return: Integer
    def self.read_uint24(io)
      payload = io.read(3)
      if payload.nil?
        raise MysqlReplicator::Error, 'payload is nil'
      end

      bytes = payload.unpack('C3').map(&:to_i)
      bytes[0] | (bytes[1] << 8) | (bytes[2] << 16)
    end

    # @rbs io: StringIO
    # @rbs return: Integer
    def self.read_int32(io)
      value = io.read(4)
      if value.nil?
        raise MysqlReplicator::Error, 'payload is nil'
      end

      value.unpack1('l<').to_i
    end

    # @rbs io: StringIO
    # @rbs return: Integer
    def self.read_uint32(io)
      value = io.read(4)
      if value.nil?
        raise MysqlReplicator::Error, 'payload is nil'
      end

      value.unpack1('V').to_i
    end

    # @rbs io: StringIO
    # @rbs return: Integer
    def self.read_uint32_big_endian(io)
      value = io.read(4)
      if value.nil?
        raise MysqlReplicator::Error, 'payload is nil'
      end

      value.unpack1('N').to_i
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
      value = io.read(8)
      if value.nil?
        raise MysqlReplicator::Error, 'payload is nil'
      end

      value.unpack1('q<').to_i
    end

    # @rbs io: StringIO
    # @rbs return: Integer
    def self.read_uint64(io)
      value = io.read(8)
      if value.nil?
        raise MysqlReplicator::Error, 'payload is nil'
      end

      value.unpack1('Q<').to_i
    end

    # @rbs io: StringIO
    # @rbs return: Float
    def self.read_float32(io)
      value = io.read(4)
      if value.nil?
        raise MysqlReplicator::Error, 'payload is nil'
      end

      value.unpack1('e').to_f
    end

    # @rbs io: StringIO
    # @rbs return: Float
    def self.read_double64(io)
      value = io.read(8)
      if value.nil?
        raise MysqlReplicator::Error, 'payload is nil'
      end

      value.unpack1('E').to_f
    end

    def self.read_array_from_int8(io, length)
      value = io.read(length) || ''
      value.unpack('C*').map(&:to_i)
    end
  end
end
