# frozen_string_literal: true

RSpec.describe MysqlReplicator::Binlogs::QueryEventParser do
  describe '#parse QUERY event payload' do
    let(:checksum_enabled) { true }

    subject do
      MysqlReplicator::Binlogs::QueryEventParser.parse(
        PayloadExample::QUERY_EVENT_PAYLOAD[19..],
        checksum_enabled
      )
    end

    it do
      expect(subject).to eq({
                              thread_id: 10,
                              exec_time: 0,
                              error_code: 0,
                              database: 'test',
                              sql: 'BEGIN'
                            })
    end
  end
end
