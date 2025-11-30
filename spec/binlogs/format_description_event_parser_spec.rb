# frozen_string_literal: true

RSpec.describe MysqlReplicator::Binlogs::FormatDescriptionEventParser do
  describe '#parse FORMAT_DESCRIPTION event payload' do
    subject do
      MysqlReplicator::Binlogs::FormatDescriptionEventParser.parse(
        PayloadExample::FORMAT_DESCRIPTION_EVENT_PAYLOAD[19..]
      )
    end

    it do
      expect(subject).to eq({ binlog_version: 4, server_version: '8.0.41' })
    end
  end
end
