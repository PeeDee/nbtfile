# nbtfile/string
#
# Copyright (c) 2011 MenTaLguY
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
