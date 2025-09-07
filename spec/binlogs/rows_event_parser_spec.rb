# frozen_string_literal: true

RSpec.describe MysqlReplicator::Binlogs::RowsEventParser do
  describe '#parse' do
    let(:payload) do
      "\x00\xFD\xCB\xBDh\x1E\x01\x00\x00\x00\x82\x02\x00\x00\x0E\b\x00\x00\x00\x00Y\x00\x00\x00\x00\x00\x01\x00\x02\x00\e\xFF\xFF\xFF\xFF\x00\x00\x00\x00\x03\x00\x00\x00\x7F\xFF\x7F\xFF\xFF\x7F\xFF\xFF\xFF\x7F\xFF\xFF\xFF\xFF\xFF\xFF\xFF\x7F\xD0\x0FI@iW\x14\x8B\n\xBF\x05@\x80\x0009C\x99\xB52\xF7\xAD\x99\xD1\x0F\x80\xF7\xADgl%%\tTest Char\x1D\x00This is a VARCHAR test string\x11Tiny text content0\x00\x00This is medium text content for testing purposes_\x00This is regular TEXT content that can be quite long and contain various characters and symbols!k\x00\x00\x00This is LONGTEXT content that can store very large amounts of text data for extensive content storage needs\nbinarydata\x1A\x00\x00medium binary data content\x18\x00regular blob binary data'\x00\x00\x00long blob binary data for large storage\nbinarytest\tvarbinary]\x00\x00\x00\x00\x04\x00\\\x00 \x00\x03\x00#\x00\x04\x00'\x00\x04\x00+\x00\x06\x00\x05\x1E\x00\f1\x00\x02;\x00\x04\x01\x00agenametagsactive\tTest User\x03\x00!\x00\f\r\x00\f\x13\x00\f\x1C\x00\x05mysql\bdatabase\x04test\x02\x01g\xFE\xEE"
    end

    let(:table_map) do
      {
        89 => {
          database: 'test',
          table: 'tests',
          table_id: 89,
          flags: 1,
          columns: [
            { ordinal_position: '1', data_type: 'int', column_name: 'id', column_type: 'int', enum_values: nil, nullable: false, column_default: nil, numeric_precision: 10, numeric_scale: 0, character_maximum_length: 0, character_set_name: nil, collation_name: nil, primary_key: true },
            { ordinal_position: '2', data_type: 'tinyint', column_name: 'tiny_int_col', column_type: 'tinyint', enum_values: nil, nullable: true, column_default: nil, numeric_precision: 3, numeric_scale: 0, character_maximum_length: 0, character_set_name: nil, collation_name: nil, primary_key: false },
            { ordinal_position: '3', data_type: 'smallint', column_name: 'small_int_col', column_type: 'smallint', enum_values: nil, nullable: true, column_default: nil, numeric_precision: 5, numeric_scale: 0, character_maximum_length: 0, character_set_name: nil, collation_name: nil, primary_key: false },
            { ordinal_position: '4', data_type: 'mediumint', column_name: 'medium_int_col', column_type: 'mediumint', enum_values: nil, nullable: true, column_default: nil, numeric_precision: 7, numeric_scale: 0, character_maximum_length: 0, character_set_name: nil, collation_name: nil, primary_key: false },
            { ordinal_position: '5', data_type: 'int', column_name: 'int_col', column_type: 'int', enum_values: nil, nullable: true, column_default: nil, numeric_precision: 10, numeric_scale: 0, character_maximum_length: 0, character_set_name: nil, collation_name: nil, primary_key: false },
            { ordinal_position: '6', data_type: 'bigint', column_name: 'big_int_col', column_type: 'bigint', enum_values: nil, nullable: true, column_default: nil, numeric_precision: 19, numeric_scale: 0, character_maximum_length: 0, character_set_name: nil, collation_name: nil, primary_key: false },
            { ordinal_position: '7', data_type: 'float', column_name: 'float_col', column_type: 'float', enum_values: nil, nullable: true, column_default: nil, numeric_precision: 12, numeric_scale: 0, character_maximum_length: 0, character_set_name: nil, collation_name: nil, primary_key: false },
            { ordinal_position: '8', data_type: 'double', column_name: 'double_col', column_type: 'double', enum_values: nil, nullable: true, column_default: nil, numeric_precision: 22, numeric_scale: 0, character_maximum_length: 0, character_set_name: nil, collation_name: nil, primary_key: false },
            { ordinal_position: '9', data_type: 'decimal', column_name: 'decimal_col', column_type: 'decimal(10,2)', enum_values: nil, nullable: true, column_default: nil, numeric_precision: 10, numeric_scale: 2, character_maximum_length: 0, character_set_name: nil, collation_name: nil, primary_key: false },
            { ordinal_position: '10', data_type: 'datetime', column_name: 'datetime_col', column_type: 'datetime', enum_values: nil, nullable: true, column_default: nil, numeric_precision: 0, numeric_scale: 0, character_maximum_length: 0, character_set_name: nil, collation_name: nil, primary_key: false },
            { ordinal_position: '11', data_type: 'date', column_name: 'date_col', column_type: 'date', enum_values: nil, nullable: true, column_default: nil, numeric_precision: 0, numeric_scale: 0, character_maximum_length: 0, character_set_name: nil, collation_name: nil, primary_key: false },
            { ordinal_position: '12', data_type: 'time', column_name: 'time_col', column_type: 'time', enum_values: nil, nullable: true, column_default: nil, numeric_precision: 0, numeric_scale: 0, character_maximum_length: 0, character_set_name: nil, collation_name: nil, primary_key: false },
            { ordinal_position: '13', data_type: 'timestamp', column_name: 'timestamp_col', column_type: 'timestamp', enum_values: nil, nullable: true, column_default: nil, numeric_precision: 0, numeric_scale: 0, character_maximum_length: 0, character_set_name: nil, collation_name: nil, primary_key: false },
            { ordinal_position: '14', data_type: 'char', column_name: 'char_col', column_type: 'char(10)', enum_values: nil, nullable: true, column_default: nil, numeric_precision: 0, numeric_scale: 0, character_maximum_length: 10, character_set_name: 'utf8mb4', collation_name: 'utf8mb4_0900_ai_ci', primary_key: false },
            { ordinal_position: '15', data_type: 'varchar', column_name: 'varchar_col', column_type: 'varchar(255)', enum_values: nil, nullable: true, column_default: nil, numeric_precision: 0, numeric_scale: 0, character_maximum_length: 255, character_set_name: 'utf8mb4', collation_name: 'utf8mb4_0900_ai_ci', primary_key: false },
            { ordinal_position: '16', data_type: 'tinytext', column_name: 'tiny_text_col', column_type: 'tinytext', enum_values: nil, nullable: true, column_default: nil, numeric_precision: 0, numeric_scale: 0, character_maximum_length: 255, character_set_name: 'utf8mb4', collation_name: 'utf8mb4_0900_ai_ci', primary_key: false },
            { ordinal_position: '17', data_type: 'mediumtext', column_name: 'medium_text_col', column_type: 'mediumtext', enum_values: nil, nullable: true, column_default: nil, numeric_precision: 0, numeric_scale: 0, character_maximum_length: 16_777_215, character_set_name: 'utf8mb4', collation_name: 'utf8mb4_0900_ai_ci', primary_key: false },
            { ordinal_position: '18', data_type: 'text', column_name: 'text_col', column_type: 'text', enum_values: nil, nullable: true, column_default: nil, numeric_precision: 0, numeric_scale: 0, character_maximum_length: 65_535, character_set_name: 'utf8mb4', collation_name: 'utf8mb4_0900_ai_ci', primary_key: false },
            { ordinal_position: '19', data_type: 'longtext', column_name: 'long_text_col', column_type: 'longtext', enum_values: nil, nullable: true, column_default: nil, numeric_precision: 0, numeric_scale: 0, character_maximum_length: 4_294_967_295, character_set_name: 'utf8mb4', collation_name: 'utf8mb4_0900_ai_ci', primary_key: false },
            { ordinal_position: '20', data_type: 'tinyblob', column_name: 'tiny_blob_col', column_type: 'tinyblob', enum_values: nil, nullable: true, column_default: nil, numeric_precision: 0, numeric_scale: 0, character_maximum_length: 255, character_set_name: nil, collation_name: nil, primary_key: false },
            { ordinal_position: '21', data_type: 'mediumblob', column_name: 'medium_blob_col', column_type: 'mediumblob', enum_values: nil, nullable: true, column_default: nil, numeric_precision: 0, numeric_scale: 0, character_maximum_length: 16_777_215, character_set_name: nil, collation_name: nil, primary_key: false },
            { ordinal_position: '22', data_type: 'blob', column_name: 'blob_col', column_type: 'blob', enum_values: nil, nullable: true, column_default: nil, numeric_precision: 0, numeric_scale: 0, character_maximum_length: 65_535, character_set_name: nil, collation_name: nil, primary_key: false },
            { ordinal_position: '23', data_type: 'longblob', column_name: 'long_blob_col', column_type: 'longblob', enum_values: nil, nullable: true, column_default: nil, numeric_precision: 0, numeric_scale: 0, character_maximum_length: 4_294_967_295, character_set_name: nil, collation_name: nil, primary_key: false },
            { ordinal_position: '24', data_type: 'binary', column_name: 'binary_col', column_type: 'binary(10)', enum_values: nil, nullable: true, column_default: nil, numeric_precision: 0, numeric_scale: 0, character_maximum_length: 10, character_set_name: nil, collation_name: nil, primary_key: false },
            { ordinal_position: '25', data_type: 'varbinary', column_name: 'var_binary_col', column_type: 'varbinary(255)', enum_values: nil, nullable: true, column_default: nil, numeric_precision: 0, numeric_scale: 0, character_maximum_length: 255, character_set_name: nil, collation_name: nil, primary_key: false },
            { ordinal_position: '26', data_type: 'json', column_name: 'json_col', column_type: 'json', enum_values: nil, nullable: true, column_default: nil, numeric_precision: 0, numeric_scale: 0, character_maximum_length: 0, character_set_name: nil, collation_name: nil, primary_key: false },
            { ordinal_position: '27', data_type: 'enum', column_name: 'enum_col', column_type: "enum('option1','option2','option3')", enum_values: ['option1', 'option2', 'option3'], nullable: true, column_default: nil, numeric_precision: 0, numeric_scale: 0, character_maximum_length: 7, character_set_name: 'utf8mb4', collation_name: 'utf8mb4_0900_ai_ci', primary_key: false }
          ]
        }
      }
    end

    subject do
      MysqlReplicator::Binlogs::RowsEventParser.parse(:WRITE_ROWS, payload[19, 623], true, table_map)
    end

    it do
      result = subject

      expect(result[:event_type]).to eq(:WRITE_ROWS)

      row = result[:rows][0][:after]
      puts row
    end
  end
end
