# frozen_string_literal: true
# rbs_inline: enabled

module MysqlReplicator
  module Binlogs
    class RotateEventParser
      # @rbs!
      #   type execution = {
      #     position: Integer,
      #     filename: String
      #   }

      # @rbs payload: String
      # @rbs checksum_enabled: bool
      # @rbs return: execution
      def self.parse(payload, checksum_enabled = false)
        # Position (8 bytes, where the next binlog starts, Little Endian 64-bit)
        position = MysqlReplicator::StringUtil.read_uint64(payload[0, 8])
        # Filename (remaining bytes, new binlog filename)
        filename = MysqlReplicator::StringUtil.read_str(payload[8..])

        # Remove checksum if present (last 4 bytes)
        if checksum_enabled && filename.length >= 4
          filename = MysqlReplicator::StringUtil.read_str(filename[0...-4])
        end

        # Find null terminator or use entire remaining data
        null_pos = filename.index("\x00")
        filename = MysqlReplicator::StringUtil.read_str(filename[0...null_pos]) if null_pos
        # Clean up any non-printable characters
        filename = filename.force_encoding(Encoding::UTF_8).scrub

        { position: position, filename: filename }
      end
    end
  end
end
