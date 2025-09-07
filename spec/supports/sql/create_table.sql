CREATE TABLE tests (
    id INT PRIMARY KEY AUTO_INCREMENT,
    
    -- Integer types
    tiny_int_col TINYINT,
    small_int_col SMALLINT,
    medium_int_col MEDIUMINT,
    int_col INT,
    big_int_col BIGINT,
    
    -- Floating point types
    float_col FLOAT,
    double_col DOUBLE,
    decimal_col DECIMAL(10,2),
    
    -- Date and time types
    datetime_col DATETIME,
    date_col DATE,
    time_col TIME,
    timestamp_col TIMESTAMP,
    
    -- String types
    char_col CHAR(10),
    varchar_col VARCHAR(255),
    tiny_text_col TINYTEXT,
    medium_text_col MEDIUMTEXT,
    text_col TEXT,
    long_text_col LONGTEXT,
    
    -- Binary types
    tiny_blob_col TINYBLOB,
    medium_blob_col MEDIUMBLOB,
    blob_col BLOB,
    long_blob_col LONGBLOB,
    binary_col BINARY(10),
    var_binary_col VARBINARY(255),
    
    -- Other types
    json_col JSON,
    enum_col ENUM('option1', 'option2', 'option3')
);
