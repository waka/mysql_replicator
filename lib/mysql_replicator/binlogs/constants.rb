# frozen_string_literal: true

module MysqlReplicator
  module Binlogs
    # MySQL Field Types contants
    module FieldTypes
      TINY_INT    = 'tinyint'
      SMALL_INT   = 'smallint'
      MEDIUM_INT  = 'mediumint'
      INT         = 'int'
      BIG_INT     = 'bigint'
      FLOAT       = 'float'
      DOUBLE      = 'double'
      DECIMAL     = 'decimal'
      DATETIME    = 'datetime'
      DATE        = 'date'
      TIME        = 'time'
      TIMESTAMP   = 'timestamp'
      CHAR        = 'char'
      VARCHAR     = 'varchar'
      TINY_TEXT   = 'tinytext'
      MEDIUM_TEXT = 'mediumtext'
      TEXT        = 'text'
      LONG_TEXT   = 'longtext'
      TINY_BLOB   = 'tinyblob'
      MEDIUM_BLOB = 'mediumblob'
      BLOB        = 'blob'
      LONG_BLOB   = 'longblob'
      BINARY      = 'binary'
      VAR_BINARY  = 'varbinary'
      JSON        = 'json'
      ENUM        = 'enum'
      UNKNOWN     = 'unknown'

      # Mapping from INFORMATION_SCHEMA DATA_TYPE to MySQL Field Type
      DATA_TYPE_MAP = {
        'tinyint' => TINY_INT,
        'smallint' => SMALL_INT,
        'mediumint' => MEDIUM_INT,
        'int' => INT,
        'bigint' => BIG_INT,
        'float' => FLOAT,
        'double' => DOUBLE,
        'decimal' => DECIMAL,
        'datetime' => DATETIME,
        'date' => DATE,
        'time' => TIME,
        'timestamp' => TIMESTAMP,
        'char' => CHAR,
        'varchar' => VARCHAR,
        'tinytext' => TINY_TEXT,
        'mediumtext' => MEDIUM_TEXT,
        'text' => TEXT,
        'longtext' => LONG_TEXT,
        'tinyblob' => TINY_BLOB,
        'mediumblob' => MEDIUM_BLOB,
        'blob' => BLOB,
        'longblob' => LONG_BLOB,
        'binary' => BINARY,
        'varbinary' => VAR_BINARY,
        'enum' => ENUM,
        'json' => JSON
      }.freeze

      def self.code_for(data_type)
        base_data_type = data_type.downcase
        DATA_TYPE_MAP[base_data_type] || UNKNOWN
      end
    end
  end
end
