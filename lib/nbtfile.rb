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
require 'stringio'

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
TAG_INDICES_BY_TYPE = {}

module Types
  tag_names = %w(End Byte Short Int Long Float Double
                 Byte_Array String List Compound)
  tag_names.each_with_index do |tag_name, index|
    tag_name = "TAG_#{tag_name}"
    symbol = tag_name.downcase.intern
    const_set tag_name, symbol
    TAGS_BY_INDEX[index] = symbol
    TAG_INDICES_BY_TYPE[symbol] = index
  end
end

module CommonMethods
  def sign_bit(n_bytes)
    1 << ((n_bytes << 3) - 1)
  end
end

module ReadMethods
  include Types
  include CommonMethods

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
    value -= ((value & sign_bit(n_bytes)) << 1)
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

  def read_value(io, type, name, state, cont)
    next_state = state

    case type
    when TAG_End
      next_state = cont
      value = nil
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
    when TAG_Byte_Array
      value = read_byte_array(io)
    when TAG_String
      value = read_string(io)
    when TAG_List
      list_type, list_length = read_list_header(io)
      next_state = ListReaderState.new(state, list_type, list_length)
      value = list_type
    when TAG_Compound
      next_state = CompoundReaderState.new(state)
    end

    [next_state, [type, name, value]]
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

  def initialize(cont)
    @cont = cont
  end

  def read_tag(io)
    type = read_type(io)

    if type != TAG_End
      name = read_string(io)
    else
      name = ""
    end

    read_value(io, type, name, self, @cont)
  end
end

class ListReaderState
  include ReadMethods
  include Types

  def initialize(cont, type, length)
    @cont = cont
    @length = length
    @offset = 0
    @type = type
  end

  def read_tag(io)
    if @offset < @length
      type = @type
    else
      type = TAG_End
    end

    index = @offset
    @offset += 1

    read_value(io, type, index, self, @cont)
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

module WriteMethods
  include Types
  include CommonMethods

  def write_integer(io, n_bytes, value)
    value -= ((value & sign_bit(n_bytes)) << 1)
    bytes = (1..n_bytes).map do |n|
      byte = (value >> ((n_bytes - n) << 3) & 0xff)
    end
    io.write(bytes.pack("C*"))
  end

  def write_byte(io, value)
    write_integer(io, 1, value)
  end

  def write_short(io, value)
    write_integer(io, 2, value)
  end

  def write_int(io, value)
    write_integer(io, 4, value)
  end

  def write_long(io, value)
    write_integer(io, 8, value)
  end

  def write_float(io, value)
    io.write([value].pack("g"))
  end

  def write_double(io, value)
    io.write([value].pack("G"))
  end

  def write_byte_array(io, value)
    write_int(io, value.length)
    io.write(value)
  end

  def write_string(io, value)
    write_short(io, value.length)
    io.write(value)
  end

  def write_type(io, type)
    write_byte(io, TAG_INDICES_BY_TYPE[type])
  end

  def write_list_header(io, type, count)
    write_type(io, type)
    write_int(io, count)
  end

  def write_value(io, type, value, capturing, state, cont)
    next_state = self

    case type
    when TAG_Byte
      write_byte(io, value)
    when TAG_Short
      write_short(io, value)
    when TAG_Int
      write_int(io, value)
    when TAG_Long
      write_long(io, value)
    when TAG_Float
      write_float(io, value)
    when TAG_Double
      write_double(io, value)
    when TAG_Byte_Array
      write_byte_array(io, value)
    when TAG_String
      write_string(io, value)
    when TAG_Float
      write_float(io, value)
    when TAG_Double
      write_double(io, value)
    when TAG_List
      next_state = ListWriterState.new(state, value, capturing)
    when TAG_Compound
      next_state = CompoundWriterState.new(state, capturing)
    when TAG_End
      next_state = cont
    else
      raise RuntimeError, "unexpected tag #{type}"
    end

    next_state
  end
end

class TopWriterState
  include WriteMethods
  include Types

  def emit_tag(io, type, name, value)
    case type
    when TAG_Compound
      write_type(io, type)
      write_string(io, name)
      end_state = EndWriterState.new()
      next_state = CompoundWriterState.new(end_state, nil)
      next_state
    end
  end
end

class CompoundWriterState
  include WriteMethods
  include Types

  def initialize(cont, capturing)
    @cont = cont
    @capturing = capturing
  end

  def emit_tag(io, type, name, value)
    out = @capturing || io

    write_type(out, type)
    write_string(out, name) unless type == TAG_End

    write_value(out, type, value, @capturing, self, @cont)
  end
end

class ListWriterState
  include WriteMethods
  include Types

  def initialize(cont, type, capturing)
    @cont = cont
    @type = type
    @count = 0
    @value = StringIO.new()
    @capturing = capturing
  end

  def emit_tag(io, type, name, value)
    if type == TAG_End
      out = @capturing || io
      write_list_header(out, @type, @count)
      out.write(@value.string)
    elsif type != @type
      raise RuntimeError, "unexpected type #{type}, expected #{@type}"
    end

    @count += 1

    write_value(@value, type, value, @value, self, @cont)
  end
end

class EndWriterState
  def emit_tag(io, type, name, value)
    raise RuntimeError, "unexpected type #{type} after end"
  end
end

class Writer
  include WriteMethods

  def initialize(stream)
    @gz = Zlib::GzipWriter.new(stream)
    @state = TopWriterState.new()
  end

  def emit_tag(tag, name, value)
    @state = @state.emit_tag(@gz, tag, name, value)
  end

  def finish
    @gz.close
  end
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
