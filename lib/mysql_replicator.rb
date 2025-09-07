# frozen_string_literal: true

require_relative 'mysql_replicator/binlog_client'
require_relative 'mysql_replicator/binlogs/column_parser'
require_relative 'mysql_replicator/binlogs/constants'
require_relative 'mysql_replicator/binlogs/event_parser'
require_relative 'mysql_replicator/binlogs/format_description_event_parser'
require_relative 'mysql_replicator/binlogs/query_event_parser'
require_relative 'mysql_replicator/binlogs/rotate_event_parser'
require_relative 'mysql_replicator/binlogs/rows_event_parser'
require_relative 'mysql_replicator/binlogs/table_map_event_parser'
require_relative 'mysql_replicator/connection'
require_relative 'mysql_replicator/connections/auth'
require_relative 'mysql_replicator/connections/handshake'
require_relative 'mysql_replicator/connections/query'
require_relative 'mysql_replicator/error'
require_relative 'mysql_replicator/logger'
require_relative 'mysql_replicator/version'

module MysqlReplicator
  def self.logger=(custom_logger)
    MysqlReplicator::Logger.logger = custom_logger
  end

  def self.test_conn
    MysqlReplicator::Connection.new(
      host: '127.0.0.1',
      port: 3306,
      user: 'root',
      password: 'root',
      database: 'test'
    )
  end

  def self.test_client(conn)
    MysqlReplicator::BinlogClient.new(conn)
  end
end
