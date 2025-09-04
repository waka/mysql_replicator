# frozen_string_literal: true

module MysqlReplicator
  module BinlogParsers
    class RotateEventParser
      def self.parse(payload, checksum_enabled = false)
        # Position (8 bytes, where the next binlog starts, Little Endian 64-bit)
        position = payload[0, 8].unpack('Q<')[0]
        # Filename (remaining bytes, new binlog filename)
        filename = payload[8..]

        # Remove checksum if present (last 4 bytes)
        if checksum_enabled && filename.length >= 4
          filename = filename[0...-4]
        end

        # Find null terminator or use entire remaining data
        null_pos = filename.index("\x00")
        filename = filename[0...null_pos] if null_pos
        # Clean up any non-printable characters
        filename = filename.force_encoding('UTF-8').scrub

        { position: position, filename: filename }
      end
    end
  end
end
