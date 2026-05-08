# MySQL Replicator

`MysqlReplicator` gem is a library for processing MySQL Binlog events with [MySQL Replication Protocol](https://dev.mysql.com/doc/dev/mysql-server/9.5.0/page_protocol_replication.html).

And also, this is lightweight because only depend on the Ruby standard library.

## Support version

- MySQL >= 8.0
- Ruby >= 3.3

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

Run with convenience method.

```rb
# `run` method: Connect to MySQL server, and start to handle replication event
MysqlReplicator.run(
  host: 'your_mysql_host', # default localhost
  port: 3307,              # default 3306
  user: 'username',        # default root
  password: 'password',    # default empty string
  database: 'test'         # default empty string
) do |binlog_event|
  # write code to process binlog event
end
```

Or run with interface manually.

```rb
# create connection to MySQL server
conn = MysqlReplicator::Connection.new(
  host: 'your_mysql_host', # default localhost
  port: 3307,              # default 3306
  user: 'username',        # default root
  password: 'password',    # default empty string
  database: 'test'         # default empty string
)
# create binlog client
client = MysqlReplicator::BinlogClient.new(conn)
# set binlog event handler
client.on do |binlog_event|
  # write code to process binlog event
end
# start replication
client.start_replication
```

If you run a create table and insert query.
```
CREATE TABLE users (
  id INT NOT NULL AUTO_INCREMENT,
  name VARCHAR(255),
  PRIMARY KEY (id)
);

INSERT INTO users VALUES ('alice');
```

MysqlReplicator received `binlog_event` with `:WRITE_ROWS` event.  
When INSERT query, you can get inserted row data.
```rb
puts binlog_event
# =>
{
  timestamp: "2025-12-01 12:00:00",
  event_type: :WRITE_ROWS,
  server_id: 1,
  execution: {
    database: 'example',
    table: 'users',
    table_id: 10,
    flags: 0,
    extra_data_length: 0,
    column_count: 2,
    rows: [
      {
         ordinal_position: 1,
         data_type: 'int',
         column_name: 'id',
         value: 1,
         primary_key: true
      },
      {
         ordinal_position: 2,
         data_type: 'varchar',
         column_name: 'name',
         value: 'alice',
         primary_key: false
      }
    ]
  }
}
```

If you run the update query.
```
UPDATE users SET name = 'bob' WHERE id = 1;
```

MysqlReplicator received `binlog_event` with `:UPDATE_ROWS` event.  
When UPDATE query, you can get row data before and after the change.
```rb
puts binlog_event
# =>
{
  timestamp: "2025-12-01 12:01:00",
  event_type: :UPDATE_ROWS,
  server_id: 1,
  execution: {
    database: 'example',
    table: 'users',
    table_id: 10,
    flags: 0,
    extra_data_length: 0,
    column_count: 2,
    rows: [
      {
        before: [
          {
            ordinal_position: 1,
            data_type: 'int',
            column_name: 'id',
            value: 1,
            primary_key: true
          },
          {
            ordinal_position: 2,
            data_type: 'varchar',
            column_name: 'name',
            value: 'alice', # before name
            primary_key: false
          }
        ],
        after: [
          {
            ordinal_position: 1,
            data_type: 'int',
            column_name: 'id',
            value: 1,
            primary_key: true
          },
          {
            ordinal_position: 2,
            data_type: 'varchar',
            column_name: 'name',
            value: 'bob', # after name
            primary_key: false
          }
        ]
      }
    ]
  }
}
```

If you run the delete query.
```
DELETE FROM users WHERE id = 1;
```

MysqlReplicator received `binlog_event` with `:DELETE_ROWS` event.  
When DELETE query, you can get row data before and after the change.
```rb
puts binlog_event
# =>
{
  timestamp: "2025-12-01 12:02:00",
  event_type: :DELETE_ROWS,
  server_id: 1,
  execution: {
    database: 'example',
    table: 'users',
    table_id: 10,
    flags: 0,
    extra_data_length: 0,
    column_count: 2,
    rows: [
      {
         ordinal_position: 1,
         data_type: 'int',
         column_name: 'id',
         value: 1,
         primary_key: true
      },
      {
         ordinal_position: 2,
         data_type: 'varchar',
         column_name: 'name',
         value: 'bob',
         primary_key: false
      }
    ]
  }
}
```

If you want to use your custom logger.

```rb
# Custom logger available
MysqlReplicator.logger = your_custom_logger
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
