require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require 'enumerator'
require 'nbtfile'
require 'stringio'
require 'zlib'

shared_examples_for "readers and writers" do
  Tokens = NBTFile::Tokens unless defined? Tokens

  def self.a_reader_or_writer(desc, serialized, tokens)
    it desc do
      check_reader_or_writer(serialized, tokens)
    end
  end

  a_reader_or_writer "should handle basic documents",
                     "\x0a\x00\x03foo" \
                     "\x00",
                     [[Tokens::TAG_COMPOUND, "foo", nil],
                      [Tokens::TAG_END, "", nil]]

  a_reader_or_writer "should treat integers as signed",
                     "\x0a\x00\x03foo" \
                     "\x03\x00\x03bar\xff\xff\xff\xfe" \
                     "\x00",
                     [[Tokens::TAG_COMPOUND, "foo", nil],
                      [Tokens::TAG_INT, "bar", -2],
                      [Tokens::TAG_END, "", nil]]

  a_reader_or_writer "should handle integer fields",
                     "\x0a\x00\x03foo" \
                     "\x03\x00\x03bar\x01\x02\x03\x04" \
                     "\x00",
                     [[Tokens::TAG_COMPOUND, "foo", nil],
                      [Tokens::TAG_INT, "bar", 0x01020304],
                      [Tokens::TAG_END, "", nil]]

  a_reader_or_writer "should handle short fields",
                     "\x0a\x00\x03foo" \
                     "\x02\x00\x03bar\x4e\x5a" \
                     "\x00",
                     [[Tokens::TAG_COMPOUND, "foo", nil],
                      [Tokens::TAG_SHORT, "bar", 0x4e5a],
                      [Tokens::TAG_END, "", nil]]

  a_reader_or_writer "should handle byte fields",
                     "\x0a\x00\x03foo" \
                     "\x01\x00\x03bar\x4e" \
                     "\x00",
                     [[Tokens::TAG_COMPOUND, "foo", nil],
                      [Tokens::TAG_BYTE, "bar", 0x4e],
                      [Tokens::TAG_END, "", nil]]

  a_reader_or_writer "should handle string fields",
                     "\x0a\x00\x03foo" \
                     "\x08\x00\x03bar\x00\x04hoge" \
                     "\x00",
                     [[Tokens::TAG_COMPOUND, "foo", nil],
                      [Tokens::TAG_STRING, "bar", "hoge"],
                      [Tokens::TAG_END, "", nil]]

  a_reader_or_writer "should handle byte array fields",
                     "\x0a\x00\x03foo" \
                     "\x07\x00\x03bar\x00\x00\x00\x05\x01\x02\x03\x04\x05" \
                     "\x00",
                     [[Tokens::TAG_COMPOUND, "foo", nil],
                      [Tokens::TAG_BYTE_ARRAY, "bar", "\x01\x02\x03\x04\x05"],
                      [Tokens::TAG_END, "", nil]]

  a_reader_or_writer "should handle long fields",
                     "\x0a\x00\x03foo" \
                     "\x04\x00\x03bar\x01\x02\x03\x04\x05\x06\x07\x08" \
                     "\x00",
                     [[Tokens::TAG_COMPOUND, "foo", nil],
                      [Tokens::TAG_LONG, "bar", 0x0102030405060708],
                      [Tokens::TAG_END, "", nil]]

  a_reader_or_writer "should handle float fields",
                     "\x0a\x00\x03foo" \
                     "\x05\x00\x03bar\x3f\xa0\x00\x00" \
                     "\x00",
                     [[Tokens::TAG_COMPOUND, "foo", nil],
                      [Tokens::TAG_FLOAT, "bar", "\x3f\xa0\x00\x00".unpack("g").first],
                      [Tokens::TAG_END, "", nil]]

  a_reader_or_writer "should handle double fields",
                     "\x0a\x00\x03foo" \
                     "\x06\x00\x03bar\x3f\xf4\x00\x00\x00\x00\x00\x00" \
                     "\x00",
                     [[Tokens::TAG_COMPOUND, "foo", nil],
                      [Tokens::TAG_DOUBLE, "bar", "\x3f\xf4\x00\x00\x00\x00\x00\x00".unpack("G").first],
                      [Tokens::TAG_END, "", nil]]

  a_reader_or_writer "should handle nested compound fields",
                     "\x0a\x00\x03foo" \
                     "\x0a\x00\x03bar" \
                     "\x01\x00\x04hoge\x4e" \
                     "\x00" \
                     "\x00",
                     [[Tokens::TAG_COMPOUND, "foo", nil],
                      [Tokens::TAG_COMPOUND, "bar", nil],
                      [Tokens::TAG_BYTE, "hoge", 0x4e],
                      [Tokens::TAG_END, "", nil],
                      [Tokens::TAG_END, "", nil]]

  simple_list_types = [
    ["bytes", Tokens::TAG_BYTE, 0x01, lambda { |ns| ns.pack("C*") }],
    ["shorts", Tokens::TAG_SHORT, 0x02, lambda { |ns| ns.pack("n*") }],
    ["ints", Tokens::TAG_INT, 0x03, lambda { |ns| ns.pack("N*") }],
    ["longs", Tokens::TAG_LONG, 0x04, lambda { |ns| ns.map { |n| [n].pack("x4N") }.join("") }],
    ["floats", Tokens::TAG_FLOAT, 0x05, lambda { |ns| ns.pack("g*") }],
    ["doubles", Tokens::TAG_DOUBLE, 0x06, lambda { |ns| ns.pack("G*") }]
  ]

  for label, type, token, pack in simple_list_types
    values = [9, 5]
    a_reader_or_writer "should handle lists of #{label}",
                       "\x0a\x00\x03foo" \
                       "\x09\x00\x03bar#{[token].pack("C")}\x00\x00\x00\x02" \
                       "#{pack.call(values)}" \
                       "\x00",
                       [[Tokens::TAG_COMPOUND, "foo", nil],
                        [Tokens::TAG_LIST, "bar", type],
                        [type, 0, values[0]],
                        [type, 1, values[1]],
                        [Tokens::TAG_END, 2, nil],
                      [Tokens::TAG_END, "", nil]] 
  end

  a_reader_or_writer "should handle nested lists",
                     "\x0a\x00\x03foo" \
                     "\x09\x00\x03bar\x09\x00\x00\x00\x01" \
                     "\x01\x00\x00\x00\x01" \
                     "\x4a" \
                     "\x00",
                     [[Tokens::TAG_COMPOUND, "foo", nil],
                      [Tokens::TAG_LIST, "bar", Tokens::TAG_LIST],
                      [Tokens::TAG_LIST, 0, Tokens::TAG_BYTE],
                      [Tokens::TAG_BYTE, 0, 0x4a],
                      [Tokens::TAG_END, 1, nil],
                      [Tokens::TAG_END, 1, nil],
                      [Tokens::TAG_END, "", nil]]
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

describe "NBTFile::load" do
  include ZlibHelpers

  def self.nbtfile_load(description, tokens, result)
    it description do
      io = StringIO.new
      writer = NBTFile::Writer.new(io)
      for type, name, value in tokens
        writer.emit_token(type, name, value)
      end
      writer.finish
      actual_result = NBTFile.load(StringIO.new(io.string))
      actual_result.should == result
    end
  end

  nbtfile_load "should generate a top-level hash",
               [[Tokens::TAG_COMPOUND, "foo", nil],
                [Tokens::TAG_BYTE, "a", 19],
                [Tokens::TAG_BYTE, "b", 23],
                [Tokens::TAG_END]],
               {"foo" => {"a" => 19, "b" => 23}}

  nbtfile_load "should map compound structures to hashes",
               [[Tokens::TAG_COMPOUND, "foo", nil],
                [Tokens::TAG_COMPOUND, "bar", nil],
                [Tokens::TAG_BYTE, "a", 123],
                [Tokens::TAG_BYTE, "b", 56],
                [Tokens::TAG_END, nil, nil],
                [Tokens::TAG_END, nil, nil]],
               {"foo" => {"bar" => {"a" => 123, "b" => 56}}}

  nbtfile_load "should map lists to arrays",
               [[Tokens::TAG_COMPOUND, "foo", nil],
                [Tokens::TAG_LIST, "bar", Tokens::TAG_BYTE],
                [Tokens::TAG_BYTE, 0, 32],
                [Tokens::TAG_BYTE, 1, 45],
                [Tokens::TAG_END, 2, nil],
                [Tokens::TAG_END, "", nil]],
               {"foo" => {"bar" => [32, 45]}}
end

describe NBTFile::Reader do
  include ZlibHelpers

  it_should_behave_like "readers and writers"

  def check_reader_or_writer(input, tokens)
    io = make_zipped_stream(input)
    reader = NBTFile::Reader.new(io)
    actual_tokens = []
    reader.each_token do |token|
      actual_tokens << token
    end
    actual_tokens.should == tokens
  end
end

describe NBTFile::Writer do
  include ZlibHelpers

  it_should_behave_like "readers and writers"

  def check_reader_or_writer(output, tokens)
    stream = StringIO.new()
    writer = NBTFile::Writer.new(stream)
    begin
      for token in tokens
        writer.emit_token(*token)
      end
    ensure
      writer.finish
    end
    actual_output = unzip_string(stream.string)
    actual_output.should == output
  end

  it "should support shorthand for emitting lists" do
    output = StringIO.new()
    writer = NBTFile::Writer.new(output)
    begin
      writer.emit_token(Tokens::TAG_COMPOUND, "test", nil)
      writer.emit_list(Tokens::TAG_BYTE, "foo") do
        writer.emit_item(12)
        writer.emit_item(43)
      end
      writer.emit_token(Tokens::TAG_END, nil, nil)
    ensure
      writer.finish
    end

    actual_output = unzip_string(output.string)
    actual_output.should == "\x0a\x00\x04test" \
                            "\x09\x00\x03foo\x01\x00\x00\x00\x02" \
                            "\x0c\x2b" \
                            "\x00"
  end

  it "should support shorthand for emitting compound structures" do
    output = StringIO.new()
    writer = NBTFile::Writer.new(output)
    begin
      writer.emit_token(Tokens::TAG_COMPOUND, "test", nil)
      writer.emit_compound("xyz") do
        writer.emit_token(Tokens::TAG_BYTE, "foo", 0x08)
        writer.emit_token(Tokens::TAG_BYTE, "bar", 0x02)
      end
      writer.emit_token(Tokens::TAG_END, nil, nil)
    ensure
      writer.finish
    end
    actual_output = unzip_string(output.string)
    actual_output.should == "\x0a\x00\x04test" \
                            "\x0a\x00\x03xyz" \
                            "\x01\x00\x03foo\x08" \
                            "\x01\x00\x03bar\x02" \
                            "\x00" \
                            "\x00"
  end
end
