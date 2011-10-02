# nbtfile/tokenizer
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

module NBTFile
module Private #:nodoc: all

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

end

class Tokenizer
  include Enumerable

  def initialize(io)
    @io = io
    @state = Private::TopTokenizerState.new()
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

  alias each each_token
end

end
