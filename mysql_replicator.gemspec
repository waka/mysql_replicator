# frozen_string_literal: true

require_relative 'lib/mysql_replicator/version'

Gem::Specification.new do |spec|
  spec.name = 'mysql_replicator'
  spec.version = MysqlReplicator::VERSION
  spec.authors = ['yo_waka']
  spec.email = ['y.wakahara@gmail.com']

  spec.summary = 'The MySQL Binlog event handler using MySQL Replication Protocol'
  spec.description = 'The MySQL Binlog event handler using MySQL Replication Protocol'
  spec.homepage = 'https://github.com/waka/mysql_replicator'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.1.0'

  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri'] = 'https://github.com/waka/mysql_replicator/blob/main/CHANGELOG.md'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'bigdecimal', '~> 3.0'
  spec.add_dependency 'logger', '~> 1.0'
end
