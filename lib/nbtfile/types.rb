# nbtfile/types
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
require 'nbtfile/tokens'

module NBTFile
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
