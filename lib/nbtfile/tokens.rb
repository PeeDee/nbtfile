# nbtfile/tokens
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

module NBTFile

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

end
