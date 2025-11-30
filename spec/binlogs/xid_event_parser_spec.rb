# frozen_string_literal: true

RSpec.describe MysqlReplicator::Binlogs::XidEventParser do
  describe '#parse XID event payload' do
    subject do
      MysqlReplicator::Binlogs::XidEventParser.parse(
        PayloadExample::XID_EVENT_PAYLOAD[19..]
      )
    end

    it do
      expect(subject).to eq({ xid: 13 })
    end
  end
end
