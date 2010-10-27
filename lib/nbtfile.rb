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

TOKEN_CLASSES_BY_INDEX = []
TOKEN_INDICES_BY_CLASS = {}

BaseToken = Struct.new :name, :value

module Tokens
  tag_names = %w(End Byte Short Int Long Float Double
                 Byte_Array String List Compound)
  tag_names.each_with_index do |tag_name, index|
    tag_name = "TAG_#{tag_name}"
    token_class = Class.new(BaseToken)

    const_set tag_name, token_class

    TOKEN_CLASSES_BY_INDEX[index] = token_class 
    TOKEN_INDICES_BY_CLASS[token_class] = index
  end
end

module CommonMethods
  def sign_bit(n_bytes)
    1 << ((n_bytes << 3) - 1)
  end
end

module ReadMethods
  include Tokens
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
      TOKEN_CLASSES_BY_INDEX.fetch(byte)
    rescue IndexError
      raise RuntimeError, "Unexpected tag ordinal #{byte}"
    end
  end

  def read_value(io, type, name, state, cont)
    next_state = state

    case
    when type == TAG_End
      next_state = cont
      value = nil
    when type == TAG_Byte
      value = read_byte(io)
    when type == TAG_Short
      value = read_short(io)
    when type == TAG_Int
      value = read_int(io)
    when type == TAG_Long
      value = read_long(io)
    when type == TAG_Float
      value = read_float(io)
    when type == TAG_Double
      value = read_double(io)
    when type == TAG_Byte_Array
      value = read_byte_array(io)
    when type == TAG_String
      value = read_string(io)
    when type == TAG_List
      list_type, list_length = read_list_header(io)
      next_state = ListReaderState.new(state, list_type, list_length)
      value = list_type
    when type == TAG_Compound
      next_state = CompoundReaderState.new(state)
    end

    [next_state, type[name, value]]
  end
end

class TopReaderState
  include ReadMethods
  include Tokens

  def get_token(io)
    type = read_type(io)
    raise RuntimeError, "expected TAG_Compound" unless type == TAG_Compound
    name = read_string(io)
    end_state = EndReaderState.new()
    next_state = CompoundReaderState.new(end_state)
    [next_state, type[name, nil]]
  end
end

class CompoundReaderState
  include ReadMethods
  include Tokens

  def initialize(cont)
    @cont = cont
  end

  def get_token(io)
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
  include Tokens

  def initialize(cont, type, length)
    @cont = cont
    @length = length
    @offset = 0
    @type = type
  end

  def get_token(io)
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
  def get_token(io)
    [self, nil]
  end
end

class Reader
  def initialize(io)
    @gz = Zlib::GzipReader.new(io)
    @state = TopReaderState.new()
  end

  def each_token
    while token = get_token()
      yield token
    end
  end

  def get_token
    @state, token = @state.get_token(@gz)
    token
  end
end

module WriteMethods
  include Tokens
  include CommonMethods

  def emit_integer(io, n_bytes, value)
    value -= ((value & sign_bit(n_bytes)) << 1)
    bytes = (1..n_bytes).map do |n|
      byte = (value >> ((n_bytes - n) << 3) & 0xff)
    end
    io.write(bytes.pack("C*"))
  end

  def emit_byte(io, value)
    emit_integer(io, 1, value)
  end

  def emit_short(io, value)
    emit_integer(io, 2, value)
  end

  def emit_int(io, value)
    emit_integer(io, 4, value)
  end

  def emit_long(io, value)
    emit_integer(io, 8, value)
  end

  def emit_float(io, value)
    io.write([value].pack("g"))
  end

  def emit_double(io, value)
    io.write([value].pack("G"))
  end

  def emit_byte_array(io, value)
    emit_int(io, value.length)
    io.write(value)
  end

  def emit_string(io, value)
    emit_short(io, value.length)
    io.write(value)
  end

  def emit_type(io, type)
    emit_byte(io, TOKEN_INDICES_BY_CLASS[type])
  end

  def emit_list_header(io, type, count)
    emit_type(io, type)
    emit_int(io, count)
  end

  def emit_value(io, type, value, capturing, state, cont)
    next_state = state

    case
    when type == TAG_Byte
      emit_byte(io, value)
    when type == TAG_Short
      emit_short(io, value)
    when type == TAG_Int
      emit_int(io, value)
    when type == TAG_Long
      emit_long(io, value)
    when type == TAG_Float
      emit_float(io, value)
    when type == TAG_Double
      emit_double(io, value)
    when type == TAG_Byte_Array
      emit_byte_array(io, value)
    when type == TAG_String
      emit_string(io, value)
    when type == TAG_Float
      emit_float(io, value)
    when type == TAG_Double
      emit_double(io, value)
    when type == TAG_List
      next_state = ListWriterState.new(state, value, capturing)
    when type == TAG_Compound
      next_state = CompoundWriterState.new(state, capturing)
    when type == TAG_End
      next_state = cont
    else
      raise RuntimeError, "Unexpected token #{type}"
    end

    next_state
  end
end

class TopWriterState
  include WriteMethods
  include Tokens

  def emit_token(io, token)
    case token
    when TAG_Compound
      emit_type(io, token.class)
      emit_string(io, token.name)
      end_state = EndWriterState.new()
      next_state = CompoundWriterState.new(end_state, nil)
      next_state
    end
  end
end

class CompoundWriterState
  include WriteMethods
  include Tokens

  def initialize(cont, capturing)
    @cont = cont
    @capturing = capturing
  end

  def emit_token(io, token)
    out = @capturing || io

    type = token.class

    emit_type(out, type)
    emit_string(out, token.name) unless type == TAG_End

    emit_value(out, type, token.value, @capturing, self, @cont)
  end

  def emit_item(io, value)
    raise RuntimeError, "not in a list"
  end
end

class ListWriterState
  include WriteMethods
  include Tokens

  def initialize(cont, type, capturing)
    @cont = cont
    @type = type
    @count = 0
    @value = StringIO.new()
    @capturing = capturing
  end

  def emit_token(io, token)
    type = token.class

    if type == TAG_End
      out = @capturing || io
      emit_list_header(out, @type, @count)
      out.write(@value.string)
    elsif type != @type
      raise RuntimeError, "unexpected token #{token.class}, expected #{@type}"
    end

    _emit_item(io, type, token.value)
  end

  def emit_item(io, value)
    _emit_item(io, @type, value)
  end

  def _emit_item(io, type, value)
    @count += 1
    emit_value(@value, type, value, @value, self, @cont)
  end
end

class EndWriterState
  def emit_token(io, token)
    raise RuntimeError, "unexpected token #{token.class} after end"
  end

  def emit_item(io, value)
    raise RuntimeError, "not in a list"
  end
end

class Writer
  include WriteMethods

  def initialize(stream)
    @gz = Zlib::GzipWriter.new(stream)
    @state = TopWriterState.new()
  end

  def emit_token(token)
    @state = @state.emit_token(@gz, token)
  end

  def emit_compound(name)
    emit_token(TAG_Compound[name, nil])
    begin
      yield
    ensure
      emit_token(TAG_End[nil, nil])
    end
  end

  def emit_list(name, type)
    emit_token(TAG_List[name, type])
    begin
      yield
    ensure
      emit_token(TAG_End[nil, nil])
    end
  end

  def emit_item(value)
    @state = @state.emit_item(@gz, value)
  end

  def finish
    @gz.close
  end
end

def self.tokenize(io)
  case io
  when String
    io = StringIO.new(io, "rb")
  end
  reader = Reader.new(io)

  reader.each_token do |token|
    yield token
  end
end

def self.emit(io)
  writer = Writer.new(io)
  begin
    yield writer
  ensure
    writer.finish
  end
end

def self.load(io)
  root = {}
  stack = [root]

  self.tokenize(io) do |token|
    case token
    when Tokens::TAG_Compound
      value = {}
    when Tokens::TAG_List
      value = []
    when Tokens::TAG_End
      stack.pop
      next
    else
      value = token.value
    end

    stack.last[token.name] = value

    case token
    when Tokens::TAG_Compound, Tokens::TAG_List
      stack.push value
    end
  end

  root.first
end

end
