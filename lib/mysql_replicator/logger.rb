# frozen_string_literal: true

require 'logger'

module MysqlReplicator
  class Logger
    @logger = ::Logger.new($stdout)
    @logger.level = ::Logger::DEBUG

    class << self
      attr_writer :logger

      def debug(message)
        @logger.debug(message)
      end

      def info(message)
        @logger.info(message)
      end

      def warn(message)
        @logger.warn(message)
      end

      def error(message)
        @logger.error(message)
      end
    end
  end
end
