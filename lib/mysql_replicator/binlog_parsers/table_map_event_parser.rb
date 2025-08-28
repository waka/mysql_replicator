# frozen_string_literal: true

module MysqlReplicator
  module BinlogParsers
    class TableMapEventParser
      def self.parse(payload, connection)
        offset = 0

        # Table ID (6 bytes)
        table_id = (payload[offset, 6] + "\x00\x00").unpack('Q<')[0]
        offset += 6

        # Flags (2 bytes)
        flags = payload[offset, 2].unpack('v')[0]
        offset += 2

        # Database name length (1 byte) + database name + null terminator
        db_name_len = payload[offset].unpack('C')[0]
        offset += 1
        database_name = payload[offset, db_name_len]
        offset += db_name_len + 1 # +1 for null terminator

        # Table name length (1 byte) + table name + null terminator
        table_name_len = payload[offset].unpack('C')[0]
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

      def self.get_table_columns(connection, database, table)
        # Create a separate connection to query table structure
        query_connection = connection.dup

        # Query table structure
        query = "SELECT DATA_TYPE, COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = '#{database}' AND TABLE_NAME = '#{table}' ORDER BY ORDINAL_POSITION"
        result = query_connection.query(query)

        # Close the separated connection
        query_connection.close

        result[:rows]
      end
    end
  end
end
