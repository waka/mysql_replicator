# MySQL Replicator

`MysqlReplicator` gem is a library for processing MySQL Binlog events using the MySQL replication protocol.

And also, this is lightweight because only depend on the Ruby standard library.

## Installation

Install the gem and add to the application's Gemfile by executing:

```bash
bundle add mysql_replicator
```

You can of course add a gem call in your Gemfile yourself.

```bash
gem 'mysql_replicator'
```

If bundler is not being used to manage dependencies, install the gem by executing:

```bash
gem install mysql_replicator
```

## Usage

```rb
# Custom logger available
MysqlReplicator.logger = your_custom_logger

# Connect to MySQL server, and start to handle replication event
MysqlReplicator.run(
  host: 'your_mysql_host', # default localhost
  port: 3307,              # default 3306
  user: 'username',        # default root
  password: 'password',    # default empty string
  database: 'test'         # default empty string
) do |binlog_event|
    # write code to process binlog event

    puts binlog_event[:timestamp]
    # => 2025-12-01 12:00:00

    puts binlog_event[:event_type]
    # => :WRITE_ROWS

    puts binlog_event[:execution]
    # => {
    #   table_id: 10,
    #   flags: 0,
    #   extra_data_length: 0,
    #   column_count: 2,
    #   rows: [
    #     {
    #        ordinal_position: 1,
    #        data_type: 'int',
    #        column_name: 'id',
    #        value: 1,
    #        primary_key: true
    #     },
    #     {
    #        ordinal_position: 2,
    #        data_type: 'varchar',
    #        column_name: 'name',
    #        value: 'alice',
    #        primary_key: false
    #     }
    #   ]
    # }
  end
```

## Development

Start MySQL server.
```
$ docker compose up
```

Start MysqlReplicator to check if local code works.
```rb
irb(main):001> MysqlReplicator.run(database: 'test') { |evt| puts evt }
```

Submit sample DDL and query to MySQL server.
Check `spec/supports/sql`.

Run spec for test.
```
$ bundle exec rspec
```

Run rubocop for linter.
```
$ bundle exec rubocop
```

Run steep for type check.
```
$ bundle exec steep check
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/waka/mysql_replicator. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/waka/mysql_replicator/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the MysqlReplicator project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/waka/mysql_replicator/blob/main/CODE_OF_CONDUCT.md).
