INSERT INTO tests (
    tiny_int_col,
    small_int_col,
    medium_int_col,
    int_col,
    big_int_col,
    float_col,
    double_col,
    decimal_col,
    datetime_col,
    date_col,
    time_col,
    timestamp_col,
    char_col,
    varchar_col,
    tiny_text_col,
    medium_text_col,
    text_col,
    long_text_col,
    tiny_blob_col,
    medium_blob_col,
    blob_col,
    long_blob_col,
    binary_col,
    var_binary_col,
    json_col,
    enum_col
) VALUES (
    -- Integer types
    127,                                    -- tiny_int_col (TINYINT: -128 to 127)
    32767,                                  -- small_int_col (SMALLINT: -32768 to 32767)
    8388607,                                -- medium_int_col (MEDIUMINT: -8388608 to 8388607)
    2147483647,                             -- int_col (INT: -2147483648 to 2147483647)
    9223372036854775807,                    -- big_int_col (BIGINT)
    
    -- Floating point types
    3.14159,                                -- float_col
    2.718281828459045,                      -- double_col
    12345.67,                               -- decimal_col
    
    -- Date and time types
    '2024-12-25 15:30:45',                  -- datetime_col
    '2024-12-25',                           -- date_col
    '15:30:45',                             -- time_col
    '2024-12-25 15:30:45',                  -- timestamp_col
    
    -- String types
    'Test Char',                            -- char_col
    'This is a VARCHAR test string',        -- varchar_col
    'Tiny text content',                    -- tiny_text_col
    'This is medium text content for testing purposes',  -- medium_text_col
    'This is regular TEXT content that can be quite long and contain various characters and symbols!', -- text_col
    'This is LONGTEXT content that can store very large amounts of text data for extensive content storage needs', -- long_text_col
    
    -- Binary types
    'binarydata',                           -- tiny_blob_col
    'medium binary data content',           -- medium_blob_col
    'regular blob binary data',             -- blob_col
    'long blob binary data for large storage', -- long_blob_col
    'binarytest',                           -- binary_col (will be padded to 10 bytes)
    'varbinary',                            -- var_binary_col
    
    -- Other types
    '{"name": "Test User", "age": 30, "active": true, "tags": ["mysql", "database", "test"]}', -- json_col
    'option2'                               -- enum_col
);
