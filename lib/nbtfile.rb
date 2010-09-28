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

TYPE_END = 0
TYPE_BYTE = 1
TYPE_SHORT = 2
TYPE_INT = 4
TYPE_LONG = 8
TYPE_COMPOUND = 10

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

  def each_event
    loop do
      type = @gz.read(1).unpack("C")[0]
      name = read_string() if type != TYPE_END
      case type
      when TYPE_END
        yield [:tag_end]
        break
      when TYPE_BYTE
        value = read_byte()
        yield [:tag_byte, name, value]
      when TYPE_INT
        value = read_int()
        yield [:tag_int, name, value]
      when TYPE_COMPOUND
        yield [:tag_compound, name]
      end
    end
  end
end



class Writer
end

end
