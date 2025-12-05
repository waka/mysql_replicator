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

## Supported event

| Event type | |
| :--- | :---: |
| ROTATE_EVENT | &#x2705; |
| FORMAT_DESCRIPTION_EVENT | &#x2705; |
| QUERY_EVENT | &#x2705; |
| TABLE_MAP_EVENT | &#x2705; |
| WRITE_ROWS_EVENT (V2) | &#x2705; |
| UPDATE_ROWS_EVENT (V2) | &#x2705; |
| DELETE_ROWS_EVENT (V2) | &#x2705; |
| XID_EVENT | &#x2705; |
| GTID_LOG_EVENT | &#x274C; |
| PREVIOUS_GTIDS_LOG_EVENT | &#x274C; |
| HEARTBEAT_LOG_EVENT | &#x274C; |
| STOP_EVENT | &#x274C; |

## Supported MySQL data type

### Numeric type

| MySQL type | |
| :--- | :---: |
| TINYINT | &#x2705; |
| SMALLINT | &#x2705; |
| MEDIUMINT | &#x2705; |
| INT | &#x2705; |
| BIGINT | &#x2705; |
| FLOAT | &#x2705; |
| DOUBLE | &#x2705; |
| DECIMAL | &#x2705; |
| BIT | &#x274C; |

### String type

| MySQL type | |
| :--- | :---: |
| CHAR | &#x2705; |
| VARCHAR | &#x2705; |
| TINYTEXT | &#x2705; |
| TEXT | &#x2705; |
| MEDIUMTEXT | &#x2705; |
| LONGTEXT | &#x2705; |
| ENUM | &#x2705; |
| SET | &#x274C; |

### Binary type

| MySQL type | |
| :--- | :---: |
| BINARY | &#x2705; |
| VARBINARY | &#x2705; |
| TINYBLOB | &#x2705; |
| BLOB | &#x2705; |
| MEDIUMBLOB | &#x2705; |
| LONGBLOB | &#x2705; |

### Date and Time type

| MySQL type | |
| :--- | :---: |
| DATE | &#x2705; |
| TIME | &#x2705; |
| DATETIME | &#x2705; |
| TIMESTAMP | &#x2705; |
| YEAR | &#x274C; |

### Special type

| MySQL type | |
| :--- | :---: |
| JSON | &#x2705; |
| GEOMETRY | &#x274C; |

## Supported Binary JSON value type

| JSON value type | |
| :--- | :---: |
| SMALL_OBJECT | &#x2705; |
| LARGE_OBJECT | &#x2705; |
| SMALL_ARRAY | &#x2705; |
| LARGE_ARRAY | &#x2705; |
| LITERAL (null / true / false) | &#x2705; |
| INT16 | &#x2705; |
| UINT16 | &#x2705; |
| INT32 | &#x2705; |
| UINT32 | &#x2705; |
| INT64 | &#x2705; |
| UINT64 | &#x2705; |
| DOUBLE | &#x2705; |
| STRING | &#x2705; |
| OPAQUE | &#x274C; |

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
