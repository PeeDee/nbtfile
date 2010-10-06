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

TAGS_BY_INDEX = []

module Types
  tag_names = %w(End Byte Short Int Long Float Double
                 Byte_Array String List Compound)
  tag_names.each do |tag_name|
    tag_name = "TAG_#{tag_name}"
    symbol = tag_name.downcase.intern
    const_set tag_name, symbol
    TAGS_BY_INDEX << symbol
  end
end

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
    byte = read_byte(io)
    begin
      TAGS_BY_INDEX.fetch(byte)
    rescue IndexError
      raise RuntimeError, "Unexpected tag #{byte}"
    end
  end
end

class TopReaderState
  include ReadMethods
  include Types

  def read_tag(io)
    type = read_type(io)
    raise RuntimeError, "expected TAG_Compound" unless type == TAG_Compound
    name = read_string(io)
    end_state = EndReaderState.new()
    next_state = CompoundReaderState.new(end_state)
    [next_state, [type, name, nil]]
  end
end

class CompoundReaderState
  include ReadMethods
  include Types

  def initialize(parent)
    @parent = parent
  end

  def read_tag(io)
    type = read_type(io)

    if type != TAG_End
      name = read_string(io)
    else
      name = ""
    end

    next_state = self

    case type
    when TAG_End
      value = nil
      next_state = @parent
    when TAG_Byte
      value = read_byte(io)
    when TAG_Short
      value = read_short(io)
    when TAG_Int
      value = read_int(io)
    when TAG_Long
      value = read_long(io)
    when TAG_String
      value = read_string(io)
    when TAG_Float
      value = read_float(io)
    when TAG_Double
      value = read_double(io)
    when TAG_Byte_Array
      value = read_byte_array(io)
    when TAG_List
      list_type, list_length = read_list_header(io)
      next_state = ListReaderState.new(self, list_type, list_length)
      value = list_type
    when TAG_Compound
      next_state = CompoundReaderState.new(self)
      value = nil
    end

    [next_state, [type, name, value]]
  end
end

class ListReaderState
  include ReadMethods
  include Types

  def initialize(parent, type, length)
    @parent = parent
    @length = length
    @offset = 0
    @type = type
  end

  def read_tag(io)
    return [@parent, [TAG_End, @length, nil]] unless @offset < @length

    next_state = self

    case @type
    when TAG_Byte
      value = read_byte(io)
    when TAG_Short
      value = read_short(io)
    when TAG_Int
      value = read_int(io)
    when TAG_Long
      value = read_long(io)
    when TAG_Float
      value = read_float(io)
    when TAG_Double
      value = read_double(io)
    when TAG_String
      value = read_string(io)
    when TAG_Byte_Array
      value = read_byte_array(io)
    when TAG_List
      list_type, list_length = read_list_header(io)
      next_state = ListReaderState.new(self, list_type, list_length)
      value = list_type
    when TAG_Compound
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

def self.load(io)
  case io
  when String
    io = StringIO.new(io, "rb")
  end

  reader = Reader.new(io)
  root = {}
  stack = [root]

  reader.each_tag do |type, name, value|
    case type
    when Types::TAG_Compound
      value = {}
    when Types::TAG_List
      value = []
    when Types::TAG_End
      stack.pop
      next
    end

    stack.last[name] = value

    case type
    when Types::TAG_Compound, Types::TAG_List
      stack.push value
    end
  end

  root
end

end
