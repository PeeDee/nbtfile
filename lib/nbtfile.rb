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

class String
  begin
    alias_method :_nbtfile_getbyte, :getbyte
  rescue NameError
    alias_method :_nbtfile_getbyte, :[]
  end

  begin
    alias_method :_nbtfile_force_encoding, :force_encoding
  rescue NameError
    def _nbtfile_force_encoding(encoding)
    end
  end
end

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

  def read_raw(n_bytes)
    data = @gz.read(n_bytes)
    raise EOFError unless data and data.length == n_bytes
    data
  end

  def read_integer(n_bytes)
    raw_value = read_raw(n_bytes)
    value = (0...n_bytes).reduce(0) do |accum, n|
      (accum << 8) | raw_value._nbtfile_getbyte(n)
    end
    value -= (value & (0x80 << ((n_bytes - 1) << 3)))
    value
  end

  def read_byte
    read_integer(1)
  end

  def read_short
    read_integer(2)
  end

  def read_int
    read_integer(4)
  end

  def read_long
    read_integer(8)
  end

  def read_string
    length = read_short()
    string = read_raw(length)
    string._nbtfile_force_encoding("UTF-8")
    string
  end

  def each_tag
    while tag = read_tag()
      yield tag
    end
  end

  def read_tag
    begin
      type = read_byte()
    rescue EOFError
      return nil
    end
    type = TYPES[type]

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
