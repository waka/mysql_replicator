# frozen_string_literal: true

RSpec.describe MysqlReplicator::Binlogs::RotateEventParser do
  describe '#parse ROTATE event payload' do
    let(:checksum_enabled) { false }

    subject do
      MysqlReplicator::Binlogs::RotateEventParser.parse(
        PayloadExample::ROTATE_EVENT_PAYLOAD[19..],
        checksum_enabled
      )
    end

    it do
      expect(subject).to eq({ position: 157, filename: 'binlog.000041' })
    end
  end
end
