# frozen_string_literal: true
# rbs_inline: enabled

module MysqlReplicator
  class StringUtil
    # @rbs payload: String | nil
    # @rbs return: String
    def self.read_str(payload)
      if payload.nil?
        raise MysqlReplicator::Error, 'payload is nil'
      end

      payload
    end

    # @rbs payload: String | nil
    # @rbs return: Integer
    def self.read_uint8(payload)
      if payload.nil?
        raise MysqlReplicator::Error, 'payload is nil'
      end

      payload.unpack1('C').to_i
    end

    # @rbs payload: String | nil
    # @rbs return: Integer
    def self.read_uint16(payload)
      if payload.nil?
        raise MysqlReplicator::Error, 'payload is nil'
      end

      payload.unpack1('v').to_i
    end

    # @rbs payload: String | nil
    # @rbs return: Integer
    def self.read_int16(payload)
      if payload.nil?
        raise MysqlReplicator::Error, 'payload is nil'
      end

      payload.unpack1('s<').to_i
    end

    # @rbs payload: String | nil
    # @rbs return: Integer
    def self.read_uint32(payload)
      if payload.nil?
        raise MysqlReplicator::Error, 'payload is nil'
      end

      payload.unpack1('V').to_i
    end

    # @rbs payload: String | nil
    # @rbs return: Integer
    def self.read_int32(payload)
      if payload.nil?
        raise MysqlReplicator::Error, 'payload is nil'
      end

      payload.unpack1('l<').to_i
    end

    # @rbs payload: String | nil
    # @rbs return: Integer
    def self.read_uint64(payload)
      if payload.nil?
        raise MysqlReplicator::Error, 'payload is nil'
      end

      payload.unpack1('Q<').to_i
    end

    # @rbs paylaod: String | nil
    # @rbs return: Integer
    def self.read_int64(payload)
      if payload.nil?
        raise MysqlReplicator::Error, 'payload is nil'
      end

      payload.unpack1('q<').to_i
    end

    # @rbs paylaod: String | nil
    # @rbs return: Float
    def self.read_double64(payload)
      if payload.nil?
        raise MysqlReplicator::Error, 'payload is nil'
      end

      payload.unpack1('E').to_f
    end

    # @rbs payload: String | nil
    # @rbs return: Array[Integer]
    def self.read_array_from_int8(payload)
      if payload.nil?
        raise MysqlReplicator::Error, 'payload is nil'
      end

      payload.unpack('C*').map(&:to_i)
    end
  end
end
