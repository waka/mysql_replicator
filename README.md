# MySQL Replicator

This library is handler for MySQL binlog events using MySQL Replication Protocol.
And this library is written by Ruby, so you can install from RubyGems.

## Installation

Install the gem and add to the application's Gemfile by executing:

```bash
bundle add mysql_replicator
```

If bundler is not being used to manage dependencies, install the gem by executing:

```bash
gem install mysql_replicator
```

## Usage

```rb
config = MysqlRepliactor::Config.new do |c|
  c.mysql_host     = 'your_mysql_host' # default 127.0.0.1
  c.mysql_port     = 3307              # default 3306
  c.mysql_user     = 'username'        # default root
  c.mysql_password = 'password'        # default nil
end

replicator = MysqlReplicator.connect!(config)
replicator.handle_binlog_event do |event|
  # handle binlog event
end
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/waka/mysql_replicator. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/waka/mysql_replicator/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the MysqlReplicator project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/waka/mysql_replicator/blob/main/CODE_OF_CONDUCT.md).
