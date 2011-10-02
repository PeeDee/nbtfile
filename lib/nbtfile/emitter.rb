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

require 'stringio'

require 'nbtfile/string'
require 'nbtfile/exceptions'
require 'nbtfile/tokens'
require 'nbtfile/io'

module NBTFile

module Private #:nodoc: all

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

end
