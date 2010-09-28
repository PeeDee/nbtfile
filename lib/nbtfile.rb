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
  :tag_byte_array,
  :tag_string,
  :tag_list,
  :tag_compound
]

module ReadMethods
  def read_raw(io, n_bytes)
    data = io.read(n_bytes)
    raise EOFError unless data and data.length == n_bytes
    data
  end

  def read_integer(io, n_bytes)
    raw_value = read_raw(io, n_bytes)
    value = (0...n_bytes).reduce(0) do |accum, n|
      (accum << 8) | raw_value._nbtfile_getbyte(n)
    end
    sign_bit = 1 << ((n_bytes << 3) - 1)
    value -= ((value & sign_bit) << 1)
    value
  end

  def read_byte(io)
    read_integer(io, 1)
  end

  def read_short(io)
    read_integer(io, 2)
  end

  def read_int(io)
    read_integer(io, 4)
  end

  def read_long(io)
    read_integer(io, 8)
  end

  def read_float(io)
    read_raw(io, 4).unpack("g").first
  end

  def read_double(io)
    read_raw(io, 8).unpack("G").first
  end

  def read_string(io)
    length = read_short(io)
    string = read_raw(io, length)
    string._nbtfile_force_encoding("UTF-8")
    string
  end

  def read_byte_array(io)
    length = read_int(io)
    read_raw(io, length)
  end

  def read_list_header(io)
    list_type = read_type(io)
    list_length = read_int(io)
    [list_type, list_length]
  end

  def read_type(io)
    TYPES[read_byte(io)]
  end
end

class TopReaderState
  include ReadMethods

  def read_tag(io)
    type = read_type(io)
    raise RuntimeError, "expected TAG_Compound" unless type == :tag_compound
    name = read_string(io)
    end_state = EndReaderState.new()
    next_state = CompoundReaderState.new(end_state)
    [next_state, [type, name, nil]]
  end
end

class CompoundReaderState
  include ReadMethods

  def initialize(parent)
    @parent = parent
  end

  def read_tag(io)
    type = read_type(io)

    if type != :tag_end
      name = read_string(io)
    else
      name = ""
    end

    next_state = self

    case type
    when :tag_end
      value = nil
      next_state = @parent
    when :tag_byte
      value = read_byte(io)
    when :tag_short
      value = read_short(io)
    when :tag_int
      value = read_int(io)
    when :tag_long
      value = read_long(io)
    when :tag_string
      value = read_string(io)
    when :tag_float
      value = read_float(io)
    when :tag_double
      value = read_double(io)
    when :tag_byte_array
      value = read_byte_array(io)
    when :tag_list
      list_type, list_length = read_list_header(io)
      next_state = ListReaderState.new(self, list_type, list_length)
      value = list_type
    when :tag_compound
      next_state = CompoundReaderState.new(self)
      value = nil
    end

    [next_state, [type, name, value]]
  end
end

class ListReaderState
  include ReadMethods

  def initialize(parent, type, length)
    @parent = parent
    @length = length
    @offset = 0
    @type = type
  end

  def read_tag(io)
    return [@parent, [:tag_end, @length, nil]] unless @offset < @length

    next_state = self

    case @type
    when :tag_byte
      value = read_byte(io)
    when :tag_short
      value = read_short(io)
    when :tag_int
      value = read_int(io)
    when :tag_long
      value = read_long(io)
    when :tag_float
      value = read_float(io)
    when :tag_double
      value = read_double(io)
    when :tag_string
      value = read_string(io)
    when :tag_byte_array
      value = read_byte_array(io)
    when :tag_list
      list_type, list_length = read_list_header(io)
      next_state = ListReaderState.new(self, list_type, list_length)
      value = list_type
    when :tag_compound
      next_state = CompoundReaderState.new(self)
      value = nil
    end
    index = @offset
    @offset += 1

    [next_state, [@type, index, value]]
  end
end

class EndReaderState
  def read_tag(io)
    [self, nil]
  end
end

class Reader
  def initialize(io)
    @gz = Zlib::GzipReader.new(io)
    @state = TopReaderState.new()
  end

  def each_tag
    while tag = read_tag()
      yield tag
    end
  end

  def read_tag
    @state, tag = @state.read_tag(@gz)
    tag
  end
end

class Writer
end

end
