# nbtfile
#
# Copyright (c) 2010 MenTaLguY
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

require 'zlib'

module NBTFile

TYPES = [
  :tag_end,
  :tag_byte,
  :tag_short,
  :tag_int,
  :tag_long,
  :tag_float,
  :tag_double,
  :tag_string,
  :tag_byte_array,
  :tag_list,
  :tag_compound
]

class Reader
  def initialize(io)
    @gz = Zlib::GzipReader.new(io)
  end

  def read_byte
    @gz.read(1).unpack("c")[0]
  end

  def read_short
    value = @gz.read(2).unpack("n")[0]
    value -= (value & 0x8000)
    value
  end

  def read_int
    value = @gz.read(4).unpack("N")[0]
    value -= (value & 0x80000000)
    value
  end

  def read_string
    length = read_short()
    content = @gz.read(length)
    # TODO: verify content length
    content
  end

  def each_tag
    while tag = read_tag()
      yield tag
    end
  end

  def read_tag
    raw_type = @gz.read(1)
    return nil unless raw_type
    type = TYPES[raw_type.unpack("C")[0]]

    if type != :tag_end
      name = read_string()
    else
      name = nil
    end

    case type
    when :tag_byte
      value = read_byte()
    when :tag_int
      value = read_int()
    else
      value = nil
    end

    [type, name, value]
  end
end



class Writer
end

end
