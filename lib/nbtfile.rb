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
require 'yaml'

class String #:nodoc: all
  begin
    alias_method :_nbtfile_getbyte, :getbyte
  rescue NameError
    alias_method :_nbtfile_getbyte, :[]
  end

  begin
    alias_method :_nbtfile_force_encoding, :force_encoding
  rescue NameError
    def _nbtfile_force_encoding(encoding) ; end
  end

  begin
    alias_method :_nbtfile_encode, :encode
  rescue NameError
    def _nbtfile_encode(encoding) ; dup ; end
  end

  begin
    alias_method :_nbtfile_bytesize, :bytesize
  rescue NameError
    alias_method :_nbtfile_bytesize, :size
  end

  begin
    alias_method :_nbtfile_valid_encoding?, :valid_encoding?
  rescue NameError
    require 'iconv'

    def _nbtfile_valid_encoding?
      begin
        Iconv.conv("UTF-8", "UTF-8", self)
        true
      rescue Iconv::IllegalSequence
        false
      end
    end
  end
end

module NBTFile

# Raised when an invalid string encoding is encountered
class EncodingError < RuntimeError
end

module Private #:nodoc: all
extend self

TOKEN_CLASSES_BY_INDEX = []
TOKEN_INDICES_BY_CLASS = {}

BaseToken = Struct.new :name, :value
end

# Classes representing NBT tokens.  Each has a constructor with
# two arguments, name and value, and corresponding accessors.
module Tokens
  tag_names = %w(End Byte Short Int Long Float Double
                 Byte_Array String List Compound)
  tag_names.each_with_index do |tag_name, index|
    tag_name = "TAG_#{tag_name}"
    token_class = Class.new(Private::BaseToken)

    const_set tag_name, token_class

    Private::TOKEN_CLASSES_BY_INDEX[index] = token_class 
    Private::TOKEN_INDICES_BY_CLASS[token_class] = index
  end
  class TAG_End
  end
  class TAG_Byte
  end
  class TAG_Short
  end
  class TAG_Int
  end
  class TAG_Long
  end
  class TAG_Float
  end
  class TAG_Double
  end
  class TAG_String
  end
  class TAG_Byte_Array
  end
  class TAG_List
  end
  class TAG_Compound
  end
end


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

class TopTokenizerState
  include ReadMethods
  include Tokens

  def get_token(io)
    type = read_type(io)
    raise RuntimeError, "expected TAG_Compound" unless type == TAG_Compound
    name = read_string(io)
    end_state = EndTokenizerState.new()
    next_state = CompoundTokenizerState.new(end_state)
    [next_state, type[name, nil]]
  end
end

class CompoundTokenizerState
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

class ListTokenizerState
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

class EndTokenizerState
  def get_token(io)
    [self, nil]
  end
end

class Tokenizer
  def initialize(io)
    @io = io
    @state = TopTokenizerState.new()
  end

  def each_token
    while token = get_token()
      yield token
    end
  end

  def get_token
    @state, token = @state.get_token(@io)
    token
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

class TopEmitterState
  include EmitMethods
  include Tokens

  def emit_token(io, token)
    case token
    when TAG_Compound
      emit_type(io, token.class)
      emit_string(io, token.name)
      end_state = EndEmitterState.new()
      next_state = CompoundEmitterState.new(end_state, nil)
      next_state
    end
  end
end

class CompoundEmitterState
  include EmitMethods
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

class ListEmitterState
  include EmitMethods
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

class EndEmitterState
  def emit_token(io, token)
    raise RuntimeError, "unexpected token #{token.class} after end"
  end

  def emit_item(io, value)
    raise RuntimeError, "not in a list"
  end
end

end
include Private

class Emitter
  include Private
  include Tokens

  def initialize(io) #:nodoc:
    @io = io
    @state = TopEmitterState.new()
  end

  # Emit a token.  See the Tokens module for a list of token types.
  def emit_token(token)
    @state = @state.emit_token(@io, token)
  end

  # Emit a TAG_Compound token, call the block, and then emit a matching
  # TAG_End token.
  def emit_compound(name) #:yields:
    emit_token(TAG_Compound[name, nil])
    begin
      yield
    ensure
      emit_token(TAG_End[nil, nil])
    end
  end

  # Emit a TAG_List token, call the block, and then emit a matching TAG_End
  # token.
  def emit_list(name, type) #:yields:
    emit_token(TAG_List[name, type])
    begin
      yield
    ensure
      emit_token(TAG_End[nil, nil])
    end
  end

  # Emits a list item, given a value (the token type is assumed based on
  # the element type of the enclosing list).
  def emit_item(value)
    @state = @state.emit_item(@io, value)
  end
end

module Private #:nodoc: all
  def coerce_to_io(io)
    case io
    when String
      StringIO.new(io, "rb")
    else
      io
    end
  end
end

# Produce a sequence of NBT tokens from a stream
def self.tokenize(io, &block) #:yields: token
  gz = Zlib::GzipReader.new(Private.coerce_to_io(io))
  tokenize_uncompressed(gz, &block)
end

def self.tokenize_uncompressed(io) #:yields: token
  reader = NBTFile::Tokenizer.new(Private.coerce_to_io(io))
  if block_given?
    reader.each_token { |token| yield token }
  else
    tokens = []
    reader.each_token { |token| tokens << token }
    tokens
  end
end

# Emit NBT tokens to a stream
def self.emit(io, &block) #:yields: emitter
  gz = Zlib::GzipWriter.new(io)
  begin
    emit_uncompressed(gz, &block)
  ensure
    gz.close
  end
end

def self.emit_uncompressed(io) #:yields: emitter
  emitter = Emitter.new(io)
  yield emitter
end

# Load an NBT file as a Ruby data structure; returns a pair containing
# the name of the top-level compound tag and its value
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

# Utility helper which transcodes a stream directly to YAML
def self.transcode_to_yaml(input, output)
  YAML.dump(load(input), output)
end

# Reads an NBT stream as a data structure and returns a pair containing the
# name of the top-level compound tag and its value.
def self.read(io)
  root = {}
  stack = [root]

  self.tokenize(io) do |token|
    case token
    when Tokens::TAG_Byte
      value = Types::Byte.new(token.value)
    when Tokens::TAG_Short
      value = Types::Short.new(token.value)
    when Tokens::TAG_Int
      value = Types::Int.new(token.value)
    when Tokens::TAG_Long
      value = Types::Long.new(token.value)
    when Tokens::TAG_Float
      value = Types::Float.new(token.value)
    when Tokens::TAG_Double
      value = Types::Double.new(token.value)
    when Tokens::TAG_String
      value = Types::String.new(token.value)
    when Tokens::TAG_Byte_Array
      value = Types::ByteArray.new(token.value)
    when Tokens::TAG_List
      tag = token.value
      case
      when tag == Tokens::TAG_Byte
        type = Types::Byte
      when tag == Tokens::TAG_Short
        type = Types::Short
      when tag == Tokens::TAG_Int
        type = Types::Int
      when tag == Tokens::TAG_Long
        type = Types::Long
      when tag == Tokens::TAG_Float
        type = Types::Float
      when tag == Tokens::TAG_Double
        type = Types::Double
      when tag == Tokens::TAG_String
        type = Types::String
      when tag == Tokens::TAG_Byte_Array
        type = Types::ByteArray
      when tag == Tokens::TAG_List
        type = Types::List
      when tag == Tokens::TAG_Compound
        type = Types::Compound
      else
        raise TypeError, "Unexpected list type #{token.value}"
      end
      value = Types::List.new(type)
    when Tokens::TAG_Compound
      value = Types::Compound.new
    when Tokens::TAG_End
      stack.pop
      next
    else
      raise TypeError, "Unexpected token type #{token.class}"
    end

    current = stack.last
    case current
    when Types::List
      current << value
    else
      current[token.name] = value
    end

    case token
    when Tokens::TAG_Compound, Tokens::TAG_List
      stack.push value
    end
  end

  root.first
end

module Private #:nodoc: all
class Writer
  def initialize(emitter)
    @emitter = emitter
  end

  def type_to_token(type)
    case
    when type == Types::Byte
      token = Tokens::TAG_Byte
    when type == Types::Short
      token = Tokens::TAG_Short
    when type == Types::Int
      token = Tokens::TAG_Int
    when type == Types::Long
      token = Tokens::TAG_Long
    when type == Types::Float
      token = Tokens::TAG_Float
    when type == Types::Double
      token = Tokens::TAG_Double
    when type == Types::String
      token = Tokens::TAG_String
    when type == Types::ByteArray
      token = Tokens::TAG_Byte_Array
    when type == Types::List
      token = Tokens::TAG_List
    when type == Types::Compound
      token = Tokens::TAG_Compound
    else
      raise TypeError, "Unexpected list type #{type}"
    end
    return token
  end

  def write_pair(name, value)
    case value
    when Types::Byte
      @emitter.emit_token(Tokens::TAG_Byte[name, value.value])
    when Types::Short
      @emitter.emit_token(Tokens::TAG_Short[name, value.value])
    when Types::Int
      @emitter.emit_token(Tokens::TAG_Int[name, value.value])
    when Types::Long
      @emitter.emit_token(Tokens::TAG_Long[name, value.value])
    when Types::Float
      @emitter.emit_token(Tokens::TAG_Float[name, value.value])
    when Types::Double
      @emitter.emit_token(Tokens::TAG_Double[name, value.value])
    when Types::String
      @emitter.emit_token(Tokens::TAG_String[name, value.value])
    when Types::ByteArray
      @emitter.emit_token(Tokens::TAG_Byte_Array[name, value.value])
    when Types::List
      token = type_to_token(value.type)
      @emitter.emit_token(Tokens::TAG_List[name, token])
      for item in value
        write_pair(nil, item)
      end
      @emitter.emit_token(Tokens::TAG_End[nil, nil])
    when Types::Compound
      @emitter.emit_token(Tokens::TAG_Compound[name, nil])
      for k, v in value
        write_pair(k, v)
      end
      @emitter.emit_token(Tokens::TAG_End[nil, nil])
    end
  end
end
end

def self.write(io, name, body)
  emit(io) do |emitter|
    writer = Writer.new(emitter)
    writer.write_pair(name, body)
  end
end

module Types
  module Private #:nodoc: all
  module Base
  end

  class BaseScalar
    include Private::Base
    include Comparable

    attr_reader :value

    def <=>(other)
      if other.kind_of? BaseScalar
        @value <=> other.value
      else
        @value <=> other
      end
    end
  end

  class BaseInteger < BaseScalar
    def self.make_subclass(n_bits)
      subclass = Class.new(self)
      limit = 1 << (n_bits - 1)
      subclass.const_set(:RANGE, -limit..(limit-1))
      subclass
    end

    def initialize(value)
      unless self.class::RANGE.include? value
        raise RangeError, "Value out of range"
      end
      int_value = value.to_int
      if int_value != value
        raise TypeError, "Not an integer"
      end
      @value = value
    end

    def ==(other)
      if other.respond_to? :to_int
        self.to_int == other.to_int
      else
        false
      end
    end

    def eql?(other)
      other.class == self.class and other.value == @value
    end

    def hash
      [self.class, @value].hash
    end

    alias_method :to_int, :value
    alias_method :to_i, :value
  end

  class BaseFloat < BaseScalar
    def initialize(value)
      unless Numeric === value
        raise TypeError
      end
      float_value = value.to_f
      @value = float_value
    end

    def ==(other)
      if Numeric === other or BaseFloat === other
        @value == other.to_f
      else
        false
      end
    end

    def eql?(other)
      other.class == self.class and other.value == @value
    end

    def hash
      [self.class, @value].hash
    end

    alias_method :to_f, :value
  end
  end
  include Private

  Byte = BaseInteger.make_subclass(8)
  class Byte
  end
  Short = BaseInteger.make_subclass(16)
  class Short
  end
  Int = BaseInteger.make_subclass(32)
  class Int
  end
  Long = BaseInteger.make_subclass(64)
  class Long
  end

  class Float < BaseFloat
  end

  class Double < BaseFloat
  end

  class String < BaseScalar
    def initialize(value)
      unless value.respond_to? :to_str
        raise TypeError, "String or string-like expected"
      end
      @value = value.to_str
    end

    def to_s ; @value.dup ; end
    alias_method :to_str, :to_s
  end

  class ByteArray
    include Private::Base

    attr_reader :value

    def initialize(value)
      unless value.respond_to? :to_str
        raise TypeError, "String or string-like expected"
      end
      @value = value.to_str
    end

    def ==(other)
      self.class == other.class && @value == other.value
    end

    def to_s ; @value.dup ; end
    alias_method :to_str, :to_s
  end

  class List
    include Private::Base
    include Enumerable

    attr_reader :type

    def initialize(type, items=[])
      @type = type
      @items = []
      for item in items
        self << item
      end
    end

    def <<(item)
      unless item.instance_of? @type
        raise TypeError, "Items should be instances of #{@type}"
      end
      @items << item
      self
    end

    def each
      if block_given?
        @items.each { |item| yield item }
        self
      else
        @items.each
      end
    end

    def to_a
      @items.dup
    end

    def length
      @items.length
    end
    alias_method :size, :length

    def ==(other)
      self.class == other.class && @items == other.to_a
    end
  end

  class Compound
    include Private::Base
    include Enumerable

    def initialize(contents={})
      @hash = {}
      @key_order = []
      for key, value in contents
        self[key] = value
      end
    end

    def has_key?(key)
      @hash.has_key? key
    end
    alias_method :include?, :has_key?

    def []=(key, value)
      unless key.instance_of? ::String
        raise TypeError, "Key must be a string"
      end
      unless value.kind_of? Private::Base
        raise TypeError, "#{value.class} is not an NBT type"
      end
      @key_order << key unless @hash.has_key? key
      @hash[key] = value
      value
    end

    def [](key)
      @hash[key]
    end

    def delete(key)
      if @hash.has_key? key
        @key_order.delete key
        @hash.delete key
      end
      self
    end

    def keys
      @key_order.dup
    end

    def values
      @key_order.map { |k| @hash[k] }
    end

    def each
      if block_given?
        @key_order.each { |k| yield k, @hash[k] }
        self
      else
        @key_order.each
      end
    end

    def to_hash
      @hash.dup
    end

    def ==(other)
      self.class == other.class && @hash == other.to_hash
    end
  end
end

end
