# frozen_string_literal: true
# rbs_inline: enabled

module MysqlReplicator
  module Binlogs
    class FormatDescriptionEventParser
      # @rbs!
      #   type execution = { binlog_version: String, server_version: String }

      # @rbs payload: String
      # @rbs return: execution
      def self.parse(payload)
        binlog_version = payload[0, 2].unpack('v')[0]
        server_version = payload[2, 50].strip.gsub("\x00", '') if payload.length >= 52

        { binlog_version: binlog_version, server_version: server_version }
      end
    end
  end
end
