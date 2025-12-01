# frozen_string_literal: true

RSpec.describe MysqlReplicator do
  it 'has a version number' do
    expect(MysqlReplicator::VERSION).not_to be nil
  end
end
