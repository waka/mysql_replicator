# frozen_string_literal: true
# rbs_inline: enabled

module MysqlReplicator
  module Binlogs
    class TableMapEventParser
      # @rbs!
      #   type columnData = {
      #     ordinal_position: Integer,
      #     data_type: String,
      #     column_name: String,
      #     column_type: String,
      #     enum_values: Array[String | Integer],
      #     nullable: bool,
      #     column_default: String | nil,
      #     numeric_precision: Integer,
      #     numeric_scale: Integer,
      #     character_maximum_length: Integer,
      #     character_set_name: String,
      #     collation_name: String,
      #     primary_key: bool
      #   }

      # @rbs!
      #   type execution = {
      #     database: String | nil,
      #     table: String | nil,
      #     table_id: Integer,
      #     columns: Array[columnData],
      #     flags: Integer
      #   }

      # @rbs payload: String
      # @rbs connection: MysqlReplicator::Connection
      # @rbs return: execution
      def self.parse(payload, connection)
        offset = 0

        # Table ID (6 bytes)
        table_id = to_little_endian(payload[0, 6].unpack('C*'))
        offset += 6

        # Flags (2 bytes)
        flags = payload[offset, 2].unpack('v')[0]
        offset += 2

        # Database name length (1 byte) + database name + null terminator
        db_name_len = payload[offset, 1].unpack('C')[0]
        offset += 1
        database_name = payload[offset, db_name_len]
        offset += db_name_len + 1 # +1 for null terminator

        # Table name length (1 byte) + table name + null terminator
        table_name_len = payload[offset, 1].unpack('C')[0]
        offset += 1
        table_name = payload[offset, table_name_len]

        # Get actual column names from table schema
        columns = get_table_columns(connection, database_name, table_name)

        {
          database: database_name,
          table: table_name,
          table_id: table_id,
          columns: columns,
          flags: flags
        }
      end

      # @rbs bytes: Array[Integer]
      # @rbs return: Integer
      def self.to_little_endian(bytes)
        result = 0
        bytes.each_with_index do |byte, i|
          result |= (byte << (i * 8))
        end
        result
      end

      # @rbs connection: MysqlReplicator::Connection
      # @rbs database: String
      # @rbs table: String
      # @rbs return: Array[columnData]
      def self.get_table_columns(connection, database, table)
        # Create a separate connection to query table structure
        query_connection = connection.dup

        # Query table structure
        # IMPORTANT: Column data is stored in ascending order of ORDINAL_POSITION
        query = <<~SQL
          SELECT
            ORDINAL_POSITION,
            DATA_TYPE,
            COLUMN_NAME,
            COLUMN_TYPE,
            IS_NULLABLE,
            COLUMN_DEFAULT,
            NUMERIC_PRECISION,
            NUMERIC_SCALE,
            CHARACTER_MAXIMUM_LENGTH,
            CHARACTER_SET_NAME,
            COLLATION_NAME,
            COLUMN_KEY
          FROM INFORMATION_SCHEMA.COLUMNS
          WHERE TABLE_SCHEMA = '#{database}'
            AND TABLE_NAME = '#{table}'
          ORDER BY ORDINAL_POSITION
        SQL
        result = query_connection.query(query)

        # Close the separated connection
        query_connection.close

        result[:rows].map do |row|
          {
            ordinal_position: row[:ordinal_position],
            data_type: row[:data_type],
            column_name: row[:column_name],
            column_type: row[:column_type],
            enum_values: extract_enum_from_column_type(row[:data_type], row[:column_type]),
            nullable: row[:is_nullable] == 'YES',
            column_default: row[:column_default],
            numeric_precision: row[:numeric_precision].to_i,
            numeric_scale: row[:numeric_scale].to_i,
            character_maximum_length: row[:character_maximum_length].to_i,
            character_set_name: row[:character_set_name],
            collation_name: row[:collation_name],
            primary_key: row[:column_key] == 'PRI'
          }
        end
      end

      # @rbs data_type: String
      # @rbs column_type: String
      # @rbs return: Array[String] | nil
      def self.extract_enum_from_column_type(data_type, column_type)
        return nil unless data_type.downcase == 'enum'

        # Extract values from ENUM('value1','value2','value3')
        if column_type =~ /enum\((.*)\)/i
          enum_string = ::Regexp.last_match(1)
          # Extract value by arround single quote
          values = enum_string.scan(/'([^']*)'/).flatten
          return values
        end

        nil
      end
    end
  end
end
