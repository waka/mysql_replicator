# frozen_string_literal: true
# rbs_inline: enabled

require 'stringio'

module MysqlReplicator
  module Binlogs
    class XidEventParser
      # @rbs!
      #   type execution = { xid: Integer }

      # @rbs payload: String
      # @rbs return: execution
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
