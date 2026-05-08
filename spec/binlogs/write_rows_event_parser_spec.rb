# frozen_string_literal: true

RSpec.describe MysqlReplicator::Binlogs::RowsEventParser do
  describe '#parse WRITE_ROWS event payload' do
    let(:checksum_enabled) { true }
    let(:table_map) do
      {
        91 => {
          database: 'test',
          table: 'tests',
          table_id: 91,
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
      MysqlReplicator::Binlogs::RowsEventParser.parse(
        :WRITE_ROWS,
        PayloadExample::WRITE_ROWS_EVENT_PAYLOAD[19..],
        checksum_enabled,
        table_map
      )
    end

    context 'database' do
      it do
        expect(subject[:database]).to eq('test')
      end
    end

    context 'table' do
      it do
        expect(subject[:table]).to eq('tests')
      end
    end

    context 'table_id' do
      it do
        expect(subject[:table_id]).to eq(91)
      end
    end

    context 'flags' do
      it do
        expect(subject[:flags]).to eq(1)
      end
    end

    context 'extra_data_length' do
      it do
        expect(subject[:extra_data_length]).to eq(2)
      end
    end

    context 'column_count' do
      it do
        expect(subject[:column_count]).to eq(27)
      end
    end

    context 'id column' do
      it do
        expect(subject[:rows][0][0]).to eq({
                                             ordinal_position: 1,
                                             data_type: 'int',
                                             column_name: 'id',
                                             value: 8,
                                             primary_key: true
                                           })
      end
    end

    context 'tinyint column' do
      it do
        expect(subject[:rows][0][1]).to eq({
                                             ordinal_position: 2,
                                             data_type: 'tinyint',
                                             column_name: 'tiny_int_col',
                                             value: 127,
                                             primary_key: false
                                           })
      end
    end

    context 'smallint column' do
      it do
        expect(subject[:rows][0][2]).to eq({
                                             ordinal_position: 3,
                                             data_type: 'smallint',
                                             column_name: 'small_int_col',
                                             value: 32_767,
                                             primary_key: false
                                           })
      end
    end

    context 'mediumint column' do
      it do
        expect(subject[:rows][0][3]).to eq({
                                             ordinal_position: 4,
                                             data_type: 'mediumint',
                                             column_name: 'medium_int_col',
                                             value: 8_388_607,
                                             primary_key: false
                                           })
      end
    end

    context 'int column' do
      it do
        expect(subject[:rows][0][4]).to eq({
                                             ordinal_position: 5,
                                             data_type: 'int',
                                             column_name: 'int_col',
                                             value: 2_147_483_647,
                                             primary_key: false
                                           })
      end
    end

    context 'bigint column' do
      it do
        expect(subject[:rows][0][5]).to eq({
                                             ordinal_position: 6,
                                             data_type: 'bigint',
                                             column_name: 'big_int_col',
                                             value: 9_223_372_036_854_775_807,
                                             primary_key: false
                                           })
      end
    end

    context 'float column' do
      it do
        expect(subject[:rows][0][6]).to eq({
                                             ordinal_position: 7,
                                             data_type: 'float',
                                             column_name: 'float_col',
                                             value: 3.141590118408203,
                                             primary_key: false
                                           })
      end
    end

    context 'double column' do
      it do
        expect(subject[:rows][0][7]).to eq({
                                             ordinal_position: 8,
                                             data_type: 'double',
                                             column_name: 'double_col',
                                             value: 2.718281828459045,
                                             primary_key: false
                                           })
      end
    end

    context 'decimal column' do
      it do
        expect(subject[:rows][0][8]).to eq({
                                             ordinal_position: 9,
                                             data_type: 'decimal',
                                             column_name: 'decimal_col',
                                             value: BigDecimal('12345.67'),
                                             primary_key: false
                                           })
      end
    end

    context 'datetime column' do
      it do
        expect(subject[:rows][0][9]).to eq({
                                             ordinal_position: 10,
                                             data_type: 'datetime',
                                             column_name: 'datetime_col',
                                             value: '2024-12-25 15:30:45',
                                             primary_key: false
                                           })
      end
    end

    context 'date column' do
      it do
        expect(subject[:rows][0][10]).to eq({
                                              ordinal_position: 11,
                                              data_type: 'date',
                                              column_name: 'date_col',
                                              value: '2024-12-25',
                                              primary_key: false
                                            })
      end
    end

    context 'time column' do
      it do
        expect(subject[:rows][0][11]).to eq({
                                              ordinal_position: 12,
                                              data_type: 'time',
                                              column_name: 'time_col',
                                              value: '15:30:45',
                                              primary_key: false
                                            })
      end
    end

    context 'timestamp column' do
      it do
        expect(subject[:rows][0][12]).to eq({
                                              ordinal_position: 13,
                                              data_type: 'timestamp',
                                              column_name: 'timestamp_col',
                                              value: 1_735_140_645,
                                              primary_key: false
                                            })
      end
    end

    context 'char column' do
      it do
        expect(subject[:rows][0][13]).to eq({
                                              ordinal_position: 14,
                                              data_type: 'char',
                                              column_name: 'char_col',
                                              value: 'Test Char',
                                              primary_key: false
                                            })
      end
    end

    context 'varchar column' do
      it do
        expect(subject[:rows][0][14]).to eq({
                                              ordinal_position: 15,
                                              data_type: 'varchar',
                                              column_name: 'varchar_col',
                                              value: 'This is a VARCHAR test string',
                                              primary_key: false
                                            })
      end
    end

    context 'tinytext column' do
      it do
        expect(subject[:rows][0][15]).to eq({
                                              ordinal_position: 16,
                                              data_type: 'tinytext',
                                              column_name: 'tiny_text_col',
                                              value: 'Tiny text content',
                                              primary_key: false
                                            })
      end
    end

    context 'mediumtext column' do
      it do
        expect(subject[:rows][0][16]).to eq({
                                              ordinal_position: 17,
                                              data_type: 'mediumtext',
                                              column_name: 'medium_text_col',
                                              value: 'This is medium text content for testing purposes',
                                              primary_key: false
                                            })
      end
    end

    context 'text column' do
      it do
        expect(subject[:rows][0][17]).to eq({
                                              ordinal_position: 18,
                                              data_type: 'text',
                                              column_name: 'text_col',
                                              value: 'This is regular TEXT content that can be quite long and contain various characters and symbols!',
                                              primary_key: false
                                            })
      end
    end

    context 'longtext column' do
      it do
        expect(subject[:rows][0][18]).to eq({
                                              ordinal_position: 19,
                                              data_type: 'longtext',
                                              column_name: 'long_text_col',
                                              value: 'This is LONGTEXT content that can store very large amounts of text data for extensive content storage needs',
                                              primary_key: false
                                            })
      end
    end

    context 'tinyblob column' do
      it do
        expect(subject[:rows][0][19]).to eq({
                                              ordinal_position: 20,
                                              data_type: 'tinyblob',
                                              column_name: 'tiny_blob_col',
                                              value: 'binarydata',
                                              primary_key: false
                                            })
      end
    end

    context 'mediumblob column' do
      it do
        expect(subject[:rows][0][20]).to eq({
                                              ordinal_position: 21,
                                              data_type: 'mediumblob',
                                              column_name: 'medium_blob_col',
                                              value: 'medium binary data content',
                                              primary_key: false
                                            })
      end
    end

    context 'blob column' do
      it do
        expect(subject[:rows][0][21]).to eq({
                                              ordinal_position: 22,
                                              data_type: 'blob',
                                              column_name: 'blob_col',
                                              value: 'regular blob binary data',
                                              primary_key: false
                                            })
      end
    end

    context 'longblob column' do
      it do
        expect(subject[:rows][0][22]).to eq({
                                              ordinal_position: 23,
                                              data_type: 'longblob',
                                              column_name: 'long_blob_col',
                                              value: 'long blob binary data for large storage',
                                              primary_key: false
                                            })
      end
    end

    context 'binary column' do
      it do
        expect(subject[:rows][0][23]).to eq({
                                              ordinal_position: 24,
                                              data_type: 'binary',
                                              column_name: 'binary_col',
                                              value: 'binarytest',
                                              primary_key: false
                                            })
      end
    end

    context 'varbinary column' do
      it do
        expect(subject[:rows][0][24]).to eq({
                                              ordinal_position: 25,
                                              data_type: 'varbinary',
                                              column_name: 'var_binary_col',
                                              value: 'varbinary',
                                              primary_key: false
                                            })
      end
    end

    context 'json column' do
      it do
        expect(subject[:rows][0][25]).to eq({
                                              ordinal_position: 26,
                                              data_type: 'json',
                                              column_name: 'json_col',
                                              value: { 'active' => true, 'age' => 30, 'name' => 'Test User', 'tags' => ['mysql', 'database', 'test'] },
                                              primary_key: false
                                            })
      end
    end

    context 'enum column' do
      it do
        expect(subject[:rows][0][26]).to eq({
                                              ordinal_position: 27,
                                              data_type: 'enum',
                                              column_name: 'enum_col',
                                              value: 'option2',
                                              primary_key: false
                                            })
      end
    end
  end
end
