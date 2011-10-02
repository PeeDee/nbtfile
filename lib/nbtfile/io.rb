# nbtfile/io
#
# Copyright (c) 2010-2011 MenTaLguY
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

require 'nbtfile/string'
require 'nbtfile/exceptions'
require 'nbtfile/tokens'

module NBTFile
module Private #:nodoc: all

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
    value = read_raw(io, length)
    value._nbtfile_force_encoding("BINARY")
    value
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
      next_state = ListTokenizerState.new(state, list_type, list_length)
      value = list_type
    when type == TAG_Compound
      next_state = CompoundTokenizerState.new(state)
    end

    [next_state, type[name, value]]
  end
end

module EmitMethods
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
    value = value.dup
    value._nbtfile_force_encoding("BINARY")
    emit_int(io, value._nbtfile_bytesize)
    io.write(value)
  end

  def emit_string(io, value)
    value = value._nbtfile_encode("UTF-8")
    unless value._nbtfile_valid_encoding?
      raise EncodingError, "Invalid character sequence"
    end
    emit_short(io, value._nbtfile_bytesize)
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
      next_state = ListEmitterState.new(state, value, capturing)
    when type == TAG_Compound
      next_state = CompoundEmitterState.new(state, capturing)
    when type == TAG_End
      next_state = cont
    else
      raise RuntimeError, "Unexpected token #{type}"
    end

    next_state
  end
end

def coerce_to_io(io)
  case io
  when String
    StringIO.new(io, "rb")
  else
    io
  end
end

end
end
