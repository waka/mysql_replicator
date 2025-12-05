# frozen_string_literal: true
# rbs_inline: enabled

module MysqlReplicator
  module Binlogs
    # MySQL Field Types contants
    module FieldTypes
      TINY_INT    = 'tinyint' #: String
      SMALL_INT   = 'smallint' #: String
      MEDIUM_INT  = 'mediumint' #: String
      INT         = 'int' #: String
      BIG_INT     = 'bigint' #: String
      FLOAT       = 'float' #: String
      DOUBLE      = 'double' #: String
      DECIMAL     = 'decimal' #: String
      DATETIME    = 'datetime' #: String
      DATE        = 'date' #: String
      TIME        = 'time' #: String
      TIMESTAMP   = 'timestamp' #: String
      CHAR        = 'char' #: String
      VARCHAR     = 'varchar' #: String
      TINY_TEXT   = 'tinytext' #: String
      MEDIUM_TEXT = 'mediumtext' #: String
      TEXT        = 'text' #: String
      LONG_TEXT   = 'longtext' #: String
      TINY_BLOB   = 'tinyblob' #: String
      MEDIUM_BLOB = 'mediumblob' #: String
      BLOB        = 'blob' #: String
      LONG_BLOB   = 'longblob' #: String
      BINARY      = 'binary' #: String
      VAR_BINARY  = 'varbinary' #: String
      JSON        = 'json' #: String
      ENUM        = 'enum' #: String
      UNKNOWN     = 'unknown' #: String

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
      }.freeze #: Hash[String, String]

      # @rbs data_type: String
      # @rbs return: String
      def self.code_for(data_type)
        base_data_type = data_type.downcase
        DATA_TYPE_MAP[base_data_type] || UNKNOWN
      end
    end
  end
end
