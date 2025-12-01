UPDATE tests SET
    -- Integer types
    tiny_int_col = -128,                    -- TINYINT: -128 to 127
    small_int_col = -32768,                 -- SMALLINT: -32768 to 32767
    medium_int_col = -8388608,              -- MEDIUMINT: -8388608 to 8388607
    int_col = -2147483648,                  -- INT: -2147483648 to 2147483647
    big_int_col = -9223372036854775808,     -- BIGINT
    
    -- Floating point types
    float_col = 1.41421,                    -- float_col (√2)
    double_col = 1.6180339887498949,        -- double_col (golden ratio)
    decimal_col = 99999.99,                 -- decimal_col
    
    -- Date and time types
    datetime_col = '2025-01-01 00:00:00',   -- datetime_col
    date_col = '2025-01-01',                -- date_col
    time_col = '23:59:59',                  -- time_col
    timestamp_col = '2025-01-01 00:00:00',  -- timestamp_col
    
    -- String types
    char_col = 'Updated',                   -- char_col
    varchar_col = 'This is an UPDATED VARCHAR test string', -- varchar_col
    tiny_text_col = 'Updated tiny text',    -- tiny_text_col
    medium_text_col = 'This is UPDATED medium text content for testing purposes', -- medium_text_col
    text_col = 'This is UPDATED TEXT content that has been modified with new characters and symbols!', -- text_col
    long_text_col = 'This is UPDATED LONGTEXT content with modified data for extensive content storage needs', -- long_text_col
    
    -- Binary types
    tiny_blob_col = 'newbinary',            -- tiny_blob_col
    medium_blob_col = 'updated medium binary data', -- medium_blob_col
    blob_col = 'updated blob binary data',  -- blob_col
    long_blob_col = 'updated long blob binary data', -- long_blob_col
    binary_col = 'newbindat',               -- binary_col (will be padded to 10 bytes)
    var_binary_col = 'newvarbin',           -- var_binary_col
    
    -- Other types
    json_col = '{"name": "Updated User", "age": 31, "active": false, "tags": ["mysql", "replication", "updated"]}', -- json_col
    enum_col = 'option3'                    -- enum_col
WHERE id = 9;
