# nbtfile/region
#
# Copyright (c) 2011 MenTaLguY
# 
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
# 
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

require 'set'

module NBTFile

class RegionFile
  module Private #:nodoc:
    extend self

    REGION_WIDTH_IN_CHUNKS = 32
    SECTOR_SIZE = 4096
    TABLE_ENTRY_SIZE = 4
    TABLE_SIZE = REGION_WIDTH_IN_CHUNKS * REGION_WIDTH_IN_CHUNKS *
                 TABLE_ENTRY_SIZE
    TIMESTAMP_TABLE_OFFSET = TABLE_SIZE
    DATA_START_OFFSET = TABLE_SIZE * 2
    DATA_START_SECTOR = DATA_START_OFFSET / SECTOR_SIZE

    DEFLATE_COMPRESSION = 2

    def length_in_sectors(length)
      (length + (SECTOR_SIZE - 1)) / SECTOR_SIZE
    end

    def chunk_to_table_offset(x, z)
      TABLE_ENTRY_SIZE * (x * REGION_WIDTH_IN_CHUNKS + z)
    end

    def read_alloc_table_entry(io, x, z)
      io.seek(chunk_to_table_offset(x, z))
      (info,) = io.read(TABLE_ENTRY_SIZE).unpack("N")
      return nil unless info
      address = (info >> 8)
      return nil if address.zero?
      length = (info & 0xff)
      [address, length]
    end

    def read_sectors(io, address, length)
      io.seek(address * SECTOR_SIZE)
      io.read(length * SECTOR_SIZE)
    end

    def write_offset_table_entry(io, x, z, address, length)
      io.seek(chunk_to_table_offset(x, z))
      info = (address << 8 | length)
      io.write([info].pack("N"))
    end

    def update_chunk_timestamp(io, x, z)
      io.seek(TIMESTAMP_TABLE_OFFSET + chunk_to_table_offset(x, z))
      io.write([Time.now.to_i].pack("N"))
    end

    def write_sectors(io, address, data)
      io.seek(address * SECTOR_SIZE)
      io.write(data)
    end
  end

  def initialize(filename)
    @filename = filename
    @high_water_mark = Private::DATA_START_SECTOR
    @live_chunks = Set.new
  end

  def get_chunk(x, z)
    begin
      File.open(@filename, "rb") do |stream|
        address, length = Private.read_alloc_table_entry(stream, x, z)
        return nil unless address
        raw_data = Private.read_sectors(stream, address, length)
        payload_length, payload = raw_data.unpack("Na*")
        case
        when payload.length < payload_length
          raise RuntimeError, "Chunk length #{payload_length} greater than "
                              "allocated length #{payload.length}"
        when payload.length > payload_length
          payload = payload[0, payload_length]
        end
        compression_type, compressed_data = payload.unpack("Ca*")
        if compression_type != Private::DEFLATE_COMPRESSION
          raise RuntimeError,
                "Unsupported compression type #{compression_type}"
        end
        Zlib::Inflate.inflate(compressed_data)
      end
    rescue Errno::ENOENT
      nil
    end
  end

  def store_chunk(x, z, content)
    @live_chunks.add [x, z]
    File.open(@filename, "w+b") do |stream|
      compressed_data = Zlib::Deflate.deflate(content,
                                              Zlib::DEFAULT_COMPRESSION)
      payload_length = compressed_data.length + 1
      payload = [payload_length, Private::DEFLATE_COMPRESSION,
                 compressed_data].pack("NCa*")
      length = Private.length_in_sectors(payload.length)
      address = @high_water_mark
      @high_water_mark += length
      Private.write_sectors(stream, address, payload)
      Private.write_offset_table_entry(stream, x, z, address, length)
      Private.update_chunk_timestamp(stream, x, z)
    end
    self
  end

  def delete_chunk(x, z)
    @live_chunks.delete [x, z]
    if @live_chunks.empty?
      begin
        File.unlink(@filename)
      rescue Errno::ENOENT
      end
    else
      File.open(@filename, "w+b") do |stream|
        Private.write_offset_table_entry(stream, x, z, 0, 0)
        Private.update_chunk_timestamp(stream, x, z)
      end
    end
    self
  end
end

end
