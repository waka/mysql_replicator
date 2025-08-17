# frozen_string_literal: true

require_relative 'mysql_replicator/connection'
require_relative 'mysql_replicator/error'
require_relative 'mysql_replicator/logger'
require_relative 'mysql_replicator/version'

module MysqlReplicator
  def self.connect(host: 'localhost', port: 3306, user: 'root', password: '', database: '')
    conn = MysqlReplicator::Connection.new(host: host, port: port, user: user, password: password, database: database)
    conn.connect
    conn
  end

  def self.handle_binlog_event(conn)
    conn.on_binlog_event do |event|
      yield event, conn if block_given?
    end
  end

  def self.logger=(custom_logger)
    MysqlReplicator::Logger.logger = custom_logger
  end
end
