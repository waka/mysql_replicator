# frozen_string_literal: true

RSpec.describe MysqlReplicator::Binlogs::RowsEventParser do
  describe '#parse UPDATE_ROWS event payload' do
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
        :UPDATE_ROWS,
        PayloadExample::UPDATE_ROWS_EVENT_PAYLOAD[19..],
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

    context 'before' do
      context 'id column' do
        it do
          row = subject[:rows][0][:before][0]
          expect(row).to eq({
                              ordinal_position: 1,
                              data_type: 'int',
                              column_name: 'id',
                              value: 9,
                              primary_key: true
                            })
        end
      end

      context 'tinyint column' do
        it do
          row = subject[:rows][0][:before][1]
          expect(row).to eq({
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
          row = subject[:rows][0][:before][2]
          expect(row).to eq({
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
          row = subject[:rows][0][:before][3]
          expect(row).to eq({
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
          row = subject[:rows][0][:before][4]
          expect(row).to eq({
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
          row = subject[:rows][0][:before][5]
          expect(row).to eq({
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
          row = subject[:rows][0][:before][6]
          expect(row).to eq({
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
          row = subject[:rows][0][:before][7]
          expect(row).to eq({
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
          row = subject[:rows][0][:before][8]
          expect(row).to eq({
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
          row = subject[:rows][0][:before][9]
          expect(row).to eq({
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
          row = subject[:rows][0][:before][10]
          expect(row).to eq({
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
          row = subject[:rows][0][:before][11]
          expect(row).to eq({
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
          row = subject[:rows][0][:before][12]
          expect(row).to eq({
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
          row = subject[:rows][0][:before][13]
          expect(row).to eq({
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
          row = subject[:rows][0][:before][14]
          expect(row).to eq({
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
          row = subject[:rows][0][:before][15]
          expect(row).to eq({
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
          row = subject[:rows][0][:before][16]
          expect(row).to eq({
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
          row = subject[:rows][0][:before][17]
          expect(row).to eq({
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
          row = subject[:rows][0][:before][18]
          expect(row).to eq({
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
          row = subject[:rows][0][:before][19]
          expect(row).to eq({
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
          row = subject[:rows][0][:before][20]
          expect(row).to eq({
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
          row = subject[:rows][0][:before][21]
          expect(row).to eq({
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
          row = subject[:rows][0][:before][22]
          expect(row).to eq({
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
          row = subject[:rows][0][:before][23]
          expect(row).to eq({
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
          row = subject[:rows][0][:before][24]
          expect(row).to eq({
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
          row = subject[:rows][0][:before][25]
          expect(row).to eq({
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
          row = subject[:rows][0][:before][26]
          expect(row).to eq({
                              ordinal_position: 27,
                              data_type: 'enum',
                              column_name: 'enum_col',
                              value: 'option2',
                              primary_key: false
                            })
        end
      end
    end

    context 'after' do
      context 'id column' do
        it do
          row = subject[:rows][0][:after][0]
          expect(row).to eq({
                              ordinal_position: 1,
                              data_type: 'int',
                              column_name: 'id',
                              value: 9,
                              primary_key: true
                            })
        end
      end

      context 'tinyint column' do
        it do
          row = subject[:rows][0][:after][1]
          expect(row).to eq({
                              ordinal_position: 2,
                              data_type: 'tinyint',
                              column_name: 'tiny_int_col',
                              value: -128,
                              primary_key: false
                            })
        end
      end

      context 'smallint column' do
        it do
          row = subject[:rows][0][:after][2]
          expect(row).to eq({
                              ordinal_position: 3,
                              data_type: 'smallint',
                              column_name: 'small_int_col',
                              value: -32_768,
                              primary_key: false
                            })
        end
      end

      context 'mediumint column' do
        it do
          row = subject[:rows][0][:after][3]
          expect(row).to eq({
                              ordinal_position: 4,
                              data_type: 'mediumint',
                              column_name: 'medium_int_col',
                              value: -8_388_608,
                              primary_key: false
                            })
        end
      end

      context 'int column' do
        it do
          row = subject[:rows][0][:after][4]
          expect(row).to eq({
                              ordinal_position: 5,
                              data_type: 'int',
                              column_name: 'int_col',
                              value: -2_147_483_648,
                              primary_key: false
                            })
        end
      end

      context 'bigint column' do
        it do
          row = subject[:rows][0][:after][5]
          expect(row).to eq({
                              ordinal_position: 6,
                              data_type: 'bigint',
                              column_name: 'big_int_col',
                              value: -9_223_372_036_854_775_808,
                              primary_key: false
                            })
        end
      end

      context 'float column' do
        it do
          row = subject[:rows][0][:after][6]
          expect(row).to eq({
                              ordinal_position: 7,
                              data_type: 'float',
                              column_name: 'float_col',
                              value: 1.4142099618911743,
                              primary_key: false
                            })
        end
      end

      context 'double column' do
        it do
          row = subject[:rows][0][:after][7]
          expect(row).to eq({
                              ordinal_position: 8,
                              data_type: 'double',
                              column_name: 'double_col',
                              value: 1.6180339887498949,
                              primary_key: false
                            })
        end
      end

      context 'decimal column' do
        it do
          row = subject[:rows][0][:after][8]
          expect(row).to eq({
                              ordinal_position: 9,
                              data_type: 'decimal',
                              column_name: 'decimal_col',
                              value: BigDecimal('99999.99'),
                              primary_key: false
                            })
        end
      end

      context 'datetime column' do
        it do
          row = subject[:rows][0][:after][9]
          expect(row).to eq({
                              ordinal_position: 10,
                              data_type: 'datetime',
                              column_name: 'datetime_col',
                              value: '2025-01-01 00:00:00',
                              primary_key: false
                            })
        end
      end

      context 'date column' do
        it do
          row = subject[:rows][0][:after][10]
          expect(row).to eq({
                              ordinal_position: 11,
                              data_type: 'date',
                              column_name: 'date_col',
                              value: '2025-01-01',
                              primary_key: false
                            })
        end
      end

      context 'time column' do
        it do
          row = subject[:rows][0][:after][11]
          expect(row).to eq({
                              ordinal_position: 12,
                              data_type: 'time',
                              column_name: 'time_col',
                              value: '23:59:59',
                              primary_key: false
                            })
        end
      end

      context 'timestamp column' do
        it do
          row = subject[:rows][0][:after][12]
          expect(row).to eq({
                              ordinal_position: 13,
                              data_type: 'timestamp',
                              column_name: 'timestamp_col',
                              value: 1_735_689_600,
                              primary_key: false
                            })
        end
      end

      context 'char column' do
        it do
          row = subject[:rows][0][:after][13]
          expect(row).to eq({
                              ordinal_position: 14,
                              data_type: 'char',
                              column_name: 'char_col',
                              value: 'Updated',
                              primary_key: false
                            })
        end
      end

      context 'varchar column' do
        it do
          row = subject[:rows][0][:after][14]
          expect(row).to eq({
                              ordinal_position: 15,
                              data_type: 'varchar',
                              column_name: 'varchar_col',
                              value: 'This is an UPDATED VARCHAR test string',
                              primary_key: false
                            })
        end
      end

      context 'tinytext column' do
        it do
          row = subject[:rows][0][:after][15]
          expect(row).to eq({
                              ordinal_position: 16,
                              data_type: 'tinytext',
                              column_name: 'tiny_text_col',
                              value: 'Updated tiny text',
                              primary_key: false
                            })
        end
      end

      context 'mediumtext column' do
        it do
          row = subject[:rows][0][:after][16]
          expect(row).to eq({
                              ordinal_position: 17,
                              data_type: 'mediumtext',
                              column_name: 'medium_text_col',
                              value: 'This is UPDATED medium text content for testing purposes',
                              primary_key: false
                            })
        end
      end

      context 'text column' do
        it do
          row = subject[:rows][0][:after][17]
          expect(row).to eq({
                              ordinal_position: 18,
                              data_type: 'text',
                              column_name: 'text_col',
                              value: 'This is UPDATED TEXT content that has been modified with new characters and symbols!',
                              primary_key: false
                            })
        end
      end

      context 'longtext column' do
        it do
          row = subject[:rows][0][:after][18]
          expect(row).to eq({
                              ordinal_position: 19,
                              data_type: 'longtext',
                              column_name: 'long_text_col',
                              value: 'This is UPDATED LONGTEXT content with modified data for extensive content storage needs',
                              primary_key: false
                            })
        end
      end

      context 'tinyblob column' do
        it do
          row = subject[:rows][0][:after][19]
          expect(row).to eq({
                              ordinal_position: 20,
                              data_type: 'tinyblob',
                              column_name: 'tiny_blob_col',
                              value: 'newbinary',
                              primary_key: false
                            })
        end
      end

      context 'mediumblob column' do
        it do
          row = subject[:rows][0][:after][20]
          expect(row).to eq({
                              ordinal_position: 21,
                              data_type: 'mediumblob',
                              column_name: 'medium_blob_col',
                              value: 'updated medium binary data',
                              primary_key: false
                            })
        end
      end

      context 'blob column' do
        it do
          row = subject[:rows][0][:after][21]
          expect(row).to eq({
                              ordinal_position: 22,
                              data_type: 'blob',
                              column_name: 'blob_col',
                              value: 'updated blob binary data',
                              primary_key: false
                            })
        end
      end

      context 'longblob column' do
        it do
          row = subject[:rows][0][:after][22]
          expect(row).to eq({
                              ordinal_position: 23,
                              data_type: 'longblob',
                              column_name: 'long_blob_col',
                              value: 'updated long blob binary data',
                              primary_key: false
                            })
        end
      end

      context 'binary column' do
        it do
          row = subject[:rows][0][:after][23]
          expect(row).to eq({
                              ordinal_position: 24,
                              data_type: 'binary',
                              column_name: 'binary_col',
                              value: 'newbindat',
                              primary_key: false
                            })
        end
      end

      context 'varbinary column' do
        it do
          row = subject[:rows][0][:after][24]
          expect(row).to eq({
                              ordinal_position: 25,
                              data_type: 'varbinary',
                              column_name: 'var_binary_col',
                              value: 'newvarbin',
                              primary_key: false
                            })
        end
      end

      context 'json column' do
        it do
          row = subject[:rows][0][:after][25]
          expect(row).to eq({
                              ordinal_position: 26,
                              data_type: 'json',
                              column_name: 'json_col',
                              value: { 'active' => false, 'age' => 31, 'name' => 'Updated User', 'tags' => ['mysql', 'replication', 'updated'] },
                              primary_key: false
                            })
        end
      end

      context 'enum column' do
        it do
          row = subject[:rows][0][:after][26]
          expect(row).to eq({
                              ordinal_position: 27,
                              data_type: 'enum',
                              column_name: 'enum_col',
                              value: 'option3',
                              primary_key: false
                            })
        end
      end
    end
  end
end
