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

module NBTFile

module Private #:nodoc:
  REGION_WIDTH_IN_CHUNKS = 32

  def self.chunk_to_offset(x, z)
    x * REGION_WIDTH_IN_CHUNKS + z
  end
end

class RegionFile
  def initialize(filename)
    @filename = filename
    @chunks = {}
  end

  def get_chunk(x, z)
    @chunks[Private.chunk_to_offset(x, z)]
  end

  def store_chunk(x, z, content, timestamp)
    @chunks[Private.chunk_to_offset(x, z)] = [content.dup, timestamp]
    File.open(@filename, "w+b") {}
    self
  end

  def delete_chunk(x, z)
    @chunks.delete Private.chunk_to_offset(x, z)
    if @chunks.empty?
      begin
        File.unlink(@filename)
      rescue Errno::ENOENT
      end
    end
    self
  end
end

end
