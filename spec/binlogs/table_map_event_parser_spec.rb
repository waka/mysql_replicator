# frozen_string_literal: true

RSpec.describe MysqlReplicator::Binlogs::TableMapEventParser do
  describe '#parse TABLE_MAP event payload' do
    let(:connection) { instance_double('MysqlReplicator::Connection') }

    subject do
      MysqlReplicator::Binlogs::TableMapEventParser.parse(
        PayloadExample::TABLE_MAP_EVENT_PAYLOAD[19..],
        connection
      )
    end

    before do
      allow(MysqlReplicator::Binlogs::TableMapEventParser).to receive(:get_table_columns)
    end

    it do
      expect(subject).to eq({
                              database: 'test',
                              table: 'tests',
                              table_id: 91,
                              columns: nil,
                              flags: 1
                            })
    end
  end
end
