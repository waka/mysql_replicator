# frozen_string_literal: true

RSpec.describe MysqlReplicator::Binlogs::RowsEventParser do
  describe '#parse' do
    # insert into users values ("tomas")
    let(:payload) do
      "Y\x00\x00\x00\x00\x00\x01\x00\x02\x00\x03\xFF\x00\x1C\x00\x00\x00\x05\x00tomash\xBD\xA5MDcS-"
    end

    let(:table_map) do
      {
        89 => {
          database: 'test',
          table: 'users',
          table_id: 95,
          flags: [],
          columns: [
            {
              ordinal_position: 1,
              data_type: 'int',
              column_name: 'id',
              column_type: 'int(11)',
              enum_values: nil,
              nullable: false,
              column_default: nil,
              numeric_precision: 0,
              numeric_scale: 0,
              character_maximum_length: 0,
              character_set_name: 'utf8mb4',
              collation_name: nil,
              primary_key: true
            },
            {
              ordinal_position: 2,
              data_type: 'varchar',
              column_name: 'name',
              column_type: 'varchar(100)',
              enum_values: nil,
              nullable: false,
              column_default: nil,
              numeric_precision: 0,
              numeric_scale: 0,
              character_maximum_length: 100,
              character_set_name: 'utf8mb4',
              collation_name: 'utfmb4_0900_ai_ci',
              primary_key: false
            },
            {
              ordinal_position: 3,
              data_type: 'timestamp',
              column_name: 'created_at',
              column_type: 'timestamp',
              enum_values: nil,
              nullable: false,
              column_default: 'CURRENT_TIMESTAMP',
              numeric_precision: 0,
              numeric_scale: 0,
              character_maximum_length: 0,
              character_set_name: nil,
              collation_name: 'utfmb4',
              primary_key: false
            }
          ]
        }
      }
    end

    subject do
      MysqlReplicator::Binlogs::RowsEventParser.parse(:WRITE_ROWS, payload, true, table_map)
    end

    it do
      result = subject

      expect(result[:table_id]).to eq(89)
      expect(result[:column_count]).to eq(3)

      row = result[:rows][0][:after]
      expect(row[:id][:value]).to eq(28)
      expect(row[:name][:value]).to eq('tomas')
      expect(row[:created_at][:value].inspect).to eq('2025-09-08 00:31:25 +0900')
    end
  end
end
