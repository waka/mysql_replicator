# frozen_string_literal: true
# rbs_inline: enabled

module MysqlReplicator
  module Binlogs
    class FormatDescriptionEventParser
      # @rbs!
      #   type execution = { binlog_version: Integer, server_version: String }

      # @rbs payload: String
      # @rbs return: execution
      def self.parse(payload)
        binlog_version = MysqlReplicator::StringUtil.read_uint16(payload[0, 2])
        server_version = if payload.length >= 52
                           MysqlReplicator::StringUtil.read_str(payload[2, 50]).strip.gsub("\x00", '')
                         else
                           ''
                         end

        { binlog_version: binlog_version, server_version: server_version }
      end
    end
  end
end
