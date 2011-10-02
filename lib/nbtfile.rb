# nbtfile
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

require 'zlib'
require 'stringio'
require 'yaml'

require 'nbtfile/string'
require 'nbtfile/exceptions'
require 'nbtfile/tokens'
require 'nbtfile/io'
require 'nbtfile/tokenizer'
require 'nbtfile/emitter'

module NBTFile

# Produce a sequence of NBT tokens from a stream
def self.tokenize(io, &block) #:yields: token
  gz = Zlib::GzipReader.new(Private.coerce_to_io(io))
  tokenize_uncompressed(gz, &block)
end

def self.tokenize_uncompressed(io) #:yields: token
  reader = Tokenizer.new(Private.coerce_to_io(io))
  if block_given?
    reader.each_token { |token| yield token }
  else
    reader
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

module Private #:nodoc:
class Writer
  include Private

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
    writer = Private::Writer.new(emitter)
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
