# frozen_string_literal: true

require 'stringio'

module MysqlReplicator
  module Binlogs
    class XidEventParser
      # @param payload [String] the event payload
      # @return [Hash] parsed XID event data
      def self.parse(payload)
        io = StringIO.new(payload)
        io.set_encoding(Encoding::BINARY)

        # XID (8 bytes)
        xid = StringIOUtil.read_uint64(io)

        { xid: xid }
      end
    end
  end
end
