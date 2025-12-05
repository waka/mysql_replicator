# frozen_string_literal: true
# rbs_inline: enabled

require 'logger'

module MysqlReplicator
  class Logger
    # @rbs self.@logger: ::Logger
    @logger = ::Logger.new($stdout)
    @logger.level = ENV.fetch('MYSQL_REPLICATOR_LOG_LEVEL', ::Logger::INFO)

    class << self
      # @rbs! attr_writer logger: ::Logger
      attr_writer :logger

      # @rbs message: String
      # @rbs return: void
      def debug(message)
        @logger.debug(message)
      end

      # @rbs message: String
      # @rbs return: void
      def info(message)
        @logger.info(message)
      end

      # @rbs message: String
      # @rbs return: void
      def warn(message)
        @logger.warn(message)
      end

      # @rbs message: String
      # @return: void
      def error(message)
        @logger.error(message)
      end
    end
  end
end
