# frozen_string_literal: true
# rbs_inline: enabled

require_relative 'mysql_replicator/binlog_client'
require_relative 'mysql_replicator/binlogs/column_parser'
require_relative 'mysql_replicator/binlogs/constants'
require_relative 'mysql_replicator/binlogs/event_parser'
require_relative 'mysql_replicator/binlogs/format_description_event_parser'
require_relative 'mysql_replicator/binlogs/json_parser'
require_relative 'mysql_replicator/binlogs/query_event_parser'
require_relative 'mysql_replicator/binlogs/rotate_event_parser'
require_relative 'mysql_replicator/binlogs/rows_event_parser'
require_relative 'mysql_replicator/binlogs/table_map_event_parser'
require_relative 'mysql_replicator/binlogs/xid_event_parser'
require_relative 'mysql_replicator/connection'
require_relative 'mysql_replicator/connections/auth'
require_relative 'mysql_replicator/connections/handshake'
require_relative 'mysql_replicator/connections/query'
require_relative 'mysql_replicator/error'
require_relative 'mysql_replicator/logger'
require_relative 'mysql_replicator/string_util'
require_relative 'mysql_replicator/string_io_util'
require_relative 'mysql_replicator/version'

module MysqlReplicator
  # @rbs host: String
  # @rbs port: Integer
  # @rbs user: String
  # @rbs password: String
  # @rbs database: String
  # @rbs &block: { (MysqlReplicator::Binlogs::EventParser::binlogEvent) -> void }?
  # @rbs return: void
  def self.run(host: '127.0.0.1', port: 3306, user: 'root', password: 'root', database: '', &block)
    conn = MysqlReplicator::Connection.new(
      host: host,
      port: port,
      user: user,
      password: password,
      database: database
    )
    client = MysqlReplicator::BinlogClient.new(conn)
    client.on(&block) if block_given?
    client.start_replication
  end

  # @rbs custom_logger: ::Logger
  # @rbs return: void
  def self.logger=(custom_logger)
    MysqlReplicator::Logger.logger = custom_logger
  end
end
