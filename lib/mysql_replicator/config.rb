# frozen_string_literal: true

module MysqlReplicator
  class Config
    attr_accessor :host, :port, :username, :password, :database

    # Initialize the configuration with default values.
    # You can override these defaults by passing a block to this initializer.
    # @example
    #   config = MysqlReplicator::Config.new do |c|
    #     c.host = 'custom_host'
    #     c.port = 1234
    #     c.username = 'custom_user'
    #     c.password = 'custom_password'
    #     c.database = 'custom_database'
    #   end
    def initialize
      @host = '127.0.0.1'
      @port = 3306
      @username = 'root'
      @password = ''
      @database = ''

      yield self if block_given?
    end
  end
end
