require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require 'enumerator'
require 'nbtfile'
require 'stringio'
require 'zlib'

shared_examples_for "readers and writers" do
  Tokens = NBTFile::Tokens unless defined? Tokens

  def self.a_reader_or_writer(desc, serialized, tokens)
    it desc do
      serialized._nbtfile_force_encoding("BINARY")
      check_reader_or_writer(serialized, tokens)
    end
  end

  a_reader_or_writer "should handle basic documents",
                     "\x0a\x00\x03foo" \
                     "\x00",
                     [Tokens::TAG_Compound["foo", nil],
                      Tokens::TAG_End["", nil]]

  a_reader_or_writer "should treat integers as signed",
                     "\x0a\x00\x03foo" \
                     "\x03\x00\x03bar\xff\xff\xff\xfe" \
                     "\x00",
                     [Tokens::TAG_Compound["foo", nil],
                      Tokens::TAG_Int["bar", -2],
                      Tokens::TAG_End["", nil]]

  a_reader_or_writer "should handle integer fields",
                     "\x0a\x00\x03foo" \
                     "\x03\x00\x03bar\x01\x02\x03\x04" \
                     "\x00",
                     [Tokens::TAG_Compound["foo", nil],
                      Tokens::TAG_Int["bar", 0x01020304],
                      Tokens::TAG_End["", nil]]

  a_reader_or_writer "should handle short fields",
                     "\x0a\x00\x03foo" \
                     "\x02\x00\x03bar\x4e\x5a" \
                     "\x00",
                     [Tokens::TAG_Compound["foo", nil],
                      Tokens::TAG_Short["bar", 0x4e5a],
                      Tokens::TAG_End["", nil]]

  a_reader_or_writer "should handle byte fields",
                     "\x0a\x00\x03foo" \
                     "\x01\x00\x03bar\x4e" \
                     "\x00",
                     [Tokens::TAG_Compound["foo", nil],
                      Tokens::TAG_Byte["bar", 0x4e],
                      Tokens::TAG_End["", nil]]

  a_reader_or_writer "should handle string fields",
                     "\x0a\x00\x03foo" \
                     "\x08\x00\x03bar\x00\x04hoge" \
                     "\x00",
                     [Tokens::TAG_Compound["foo", nil],
                      Tokens::TAG_String["bar", "hoge"],
                      Tokens::TAG_End["", nil]]

  a_reader_or_writer "should handle byte array fields",
                     "\x0a\x00\x03foo" \
                     "\x07\x00\x03bar\x00\x00\x00\x05\x01\x02\x03\x04\x05" \
                     "\x00",
                     [Tokens::TAG_Compound["foo", nil],
                      Tokens::TAG_Byte_Array["bar", "\x01\x02\x03\x04\x05"],
                      Tokens::TAG_End["", nil]]

  a_reader_or_writer "should handle long fields",
                     "\x0a\x00\x03foo" \
                     "\x04\x00\x03bar\x01\x02\x03\x04\x05\x06\x07\x08" \
                     "\x00",
                     [Tokens::TAG_Compound["foo", nil],
                      Tokens::TAG_Long["bar", 0x0102030405060708],
                      Tokens::TAG_End["", nil]]

  a_reader_or_writer "should handle float fields",
                     "\x0a\x00\x03foo" \
                     "\x05\x00\x03bar\x3f\xa0\x00\x00" \
                     "\x00",
                     [Tokens::TAG_Compound["foo", nil],
                      Tokens::TAG_Float["bar", "\x3f\xa0\x00\x00".unpack("g").first],
                      Tokens::TAG_End["", nil]]

  a_reader_or_writer "should handle double fields",
                     "\x0a\x00\x03foo" \
                     "\x06\x00\x03bar\x3f\xf4\x00\x00\x00\x00\x00\x00" \
                     "\x00",
                     [Tokens::TAG_Compound["foo", nil],
                      Tokens::TAG_Double["bar", "\x3f\xf4\x00\x00\x00\x00\x00\x00".unpack("G").first],
                      Tokens::TAG_End["", nil]]

  a_reader_or_writer "should handle nested compound fields",
                     "\x0a\x00\x03foo" \
                     "\x0a\x00\x03bar" \
                     "\x01\x00\x04hoge\x4e" \
                     "\x00" \
                     "\x00",
                     [Tokens::TAG_Compound["foo", nil],
                      Tokens::TAG_Compound["bar", nil],
                      Tokens::TAG_Byte["hoge", 0x4e],
                      Tokens::TAG_End["", nil],
                      Tokens::TAG_End["", nil]]

  simple_list_types = [
    ["bytes", Tokens::TAG_Byte, 0x01, lambda { |ns| ns.pack("C*") }],
    ["shorts", Tokens::TAG_Short, 0x02, lambda { |ns| ns.pack("n*") }],
    ["ints", Tokens::TAG_Int, 0x03, lambda { |ns| ns.pack("N*") }],
    ["longs", Tokens::TAG_Long, 0x04, lambda { |ns| ns.map { |n| [n].pack("x4N") }.join("") }],
    ["floats", Tokens::TAG_Float, 0x05, lambda { |ns| ns.pack("g*") }],
    ["doubles", Tokens::TAG_Double, 0x06, lambda { |ns| ns.pack("G*") }]
  ]

  for label, type, token, pack in simple_list_types
    values = [9, 5]
    a_reader_or_writer "should handle lists of #{label}",
                       "\x0a\x00\x03foo" \
                       "\x09\x00\x03bar#{[token].pack("C")}\x00\x00\x00\x02" \
                       "#{pack.call(values)}" \
                       "\x00",
                       [Tokens::TAG_Compound["foo", nil],
                        Tokens::TAG_List["bar", type],
                        type[0, values[0]],
                        type[1, values[1]],
                        Tokens::TAG_End[2, nil],
                      Tokens::TAG_End["", nil]] 
  end

  a_reader_or_writer "should handle nested lists",
                     "\x0a\x00\x03foo" \
                     "\x09\x00\x03bar\x09\x00\x00\x00\x01" \
                     "\x01\x00\x00\x00\x01" \
                     "\x4a" \
                     "\x00",
                     [Tokens::TAG_Compound["foo", nil],
                      Tokens::TAG_List["bar", Tokens::TAG_List],
                      Tokens::TAG_List[0, Tokens::TAG_Byte],
                      Tokens::TAG_Byte[0, 0x4a],
                      Tokens::TAG_End[1, nil],
                      Tokens::TAG_End[1, nil],
                      Tokens::TAG_End["", nil]]
end

describe "NBTFile::tokenize" do
  include ZlibHelpers

  it_should_behave_like "readers and writers"

  def check_reader_or_writer(input, tokens)
    io = make_zipped_stream(input)
    actual_tokens = []
    NBTFile.tokenize(io) do |token|
      actual_tokens << token
    end
    actual_tokens.should == tokens
  end
end

describe "NBTFile::tokenize without a block" do
  include ZlibHelpers

  it_should_behave_like "readers and writers"

  def check_reader_or_writer(input, tokens)
    io = make_zipped_stream(input)
    actual_tokens = NBTFile.tokenize(io)
    actual_tokens.should be_a_kind_of(Enumerable)
    actual_tokens.to_a.should == tokens
  end
end

describe "NBTFile::emit" do
  include ZlibHelpers

  it_should_behave_like "readers and writers"

  def check_reader_or_writer(output, tokens)
    io = StringIO.new()
    NBTFile.emit(io) do |writer|
      for token in tokens
        writer.emit_token(token)
      end
    end
    actual_output = unzip_string(io.string)
    actual_output.should == output
  end

  def self.emit_shorthand(description, output, &block)
    it description do
      io = StringIO.new()
      NBTFile.emit(io, &block)
      actual_output = unzip_string(io.string)
      actual_output.should == output
    end
  end

  emit_shorthand "should support shorthand for emitting lists",
                 "\x0a\x00\x04test" \
                 "\x09\x00\x03foo\x01\x00\x00\x00\x02" \
                 "\x0c\x2b" \
                 "\x00" do |writer|
    writer.emit_token(Tokens::TAG_Compound["test", nil])
    writer.emit_list("foo", Tokens::TAG_Byte) do
      writer.emit_item(12)
      writer.emit_item(43)
    end
    writer.emit_token(Tokens::TAG_End[nil, nil])
  end

  emit_shorthand "should support shorthand for emitting compound structures",
                 "\x0a\x00\x04test" \
                 "\x0a\x00\x03xyz" \
                 "\x01\x00\x03foo\x08" \
                 "\x01\x00\x03bar\x02" \
                 "\x00" \
                 "\x00" do |writer|
    writer.emit_token(Tokens::TAG_Compound["test", nil])
    writer.emit_compound("xyz") do
      writer.emit_token(Tokens::TAG_Byte["foo", 0x08])
      writer.emit_token(Tokens::TAG_Byte["bar", 0x02])
    end
    writer.emit_token(Tokens::TAG_End[nil, nil])
  end
end

describe "NBTFile::load" do
  include ZlibHelpers

  def self.nbtfile_load(description, tokens, result)
    it description do
      io = StringIO.new()
      NBTFile.emit(io) do |writer|
        for token in tokens
          writer.emit_token(token)
        end
      end
      actual_result = NBTFile.load(StringIO.new(io.string))
      actual_result.should == result
    end
  end

  nbtfile_load "should generate a top-level pair",
               [Tokens::TAG_Compound["foo", nil],
                Tokens::TAG_Byte["a", 19],
                Tokens::TAG_Byte["b", 23],
                Tokens::TAG_End[nil, nil]],
               ["foo", {"a" => 19, "b" => 23}]

  nbtfile_load "should map compound structures to hashes",
               [Tokens::TAG_Compound["foo", nil],
                Tokens::TAG_Compound["bar", nil],
                Tokens::TAG_Byte["a", 123],
                Tokens::TAG_Byte["b", 56],
                Tokens::TAG_End[nil, nil],
                Tokens::TAG_End[nil, nil]],
               ["foo", {"bar" => {"a" => 123, "b" => 56}}]

  nbtfile_load "should map lists to arrays",
               [Tokens::TAG_Compound["foo", nil],
                Tokens::TAG_List["bar", Tokens::TAG_Byte],
                Tokens::TAG_Byte[0, 32],
                Tokens::TAG_Byte[1, 45],
                Tokens::TAG_End[2, nil],
                Tokens::TAG_End["", nil]],
               ["foo", {"bar" => [32, 45]}]
end
