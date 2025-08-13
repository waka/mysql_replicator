# frozen_string_literal: true

require_relative 'mysql_replicator/connection'
require_relative 'mysql_replicator/error'
require_relative 'mysql_replicator/logger'
require_relative 'mysql_replicator/version'

module MysqlReplicator
  def self.logger=(custom_logger)
    MysqlReplicator::Logger.logger = custom_logger
  end
end
