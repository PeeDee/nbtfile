require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require 'enumerator'
require 'nbtfile'
require 'stringio'
require 'zlib'

shared_examples_for "readers and writers" do
  Tokens = NBTFile::Tokens unless defined? Tokens
  Types = NBTFile::Types unless defined? Types

  def self.a_reader_or_writer(desc, serialized, tokens, tree)
    it desc do
      serialized._nbtfile_force_encoding("BINARY")
      check_reader_or_writer(serialized, tokens, tree)
    end
  end

  a_reader_or_writer "should handle basic documents",
                     "\x0a\x00\x03foo" \
                     "\x00",
                     [Tokens::TAG_Compound["foo", nil],
                      Tokens::TAG_End["", nil]],
                     ["foo", Types::Compound.new()]

  a_reader_or_writer "should treat integers as signed",
                     "\x0a\x00\x03foo" \
                     "\x03\x00\x03bar\xff\xff\xff\xfe" \
                     "\x00",
                     [Tokens::TAG_Compound["foo", nil],
                      Tokens::TAG_Int["bar", -2],
                      Tokens::TAG_End["", nil]],
                     ["foo",
                      Types::Compound.new({
                        "bar" => Types::Int.new(-2)})]

  a_reader_or_writer "should handle integer fields",
                     "\x0a\x00\x03foo" \
                     "\x03\x00\x03bar\x01\x02\x03\x04" \
                     "\x00",
                     [Tokens::TAG_Compound["foo", nil],
                      Tokens::TAG_Int["bar", 0x01020304],
                      Tokens::TAG_End["", nil]],
                     ["foo",
                      Types::Compound.new({
                        "bar" => Types::Int.new(0x01020304)})]

  a_reader_or_writer "should handle short fields",
                     "\x0a\x00\x03foo" \
                     "\x02\x00\x03bar\x4e\x5a" \
                     "\x00",
                     [Tokens::TAG_Compound["foo", nil],
                      Tokens::TAG_Short["bar", 0x4e5a],
                      Tokens::TAG_End["", nil]],
                     ["foo",
                      Types::Compound.new({
                        "bar" => Types::Short.new(0x4e5a)})]

  a_reader_or_writer "should handle byte fields",
                     "\x0a\x00\x03foo" \
                     "\x01\x00\x03bar\x4e" \
                     "\x00",
                     [Tokens::TAG_Compound["foo", nil],
                      Tokens::TAG_Byte["bar", 0x4e],
                      Tokens::TAG_End["", nil]],
                     ["foo",
                      Types::Compound.new({
                        "bar" => Types::Byte.new(0x4e)})]

  a_reader_or_writer "should handle string fields",
                     "\x0a\x00\x03foo" \
                     "\x08\x00\x03bar\x00\x04hoge" \
                     "\x00",
                     [Tokens::TAG_Compound["foo", nil],
                      Tokens::TAG_String["bar", "hoge"],
                      Tokens::TAG_End["", nil]],
                     ["foo",
                      Types::Compound.new({
                        "bar" => Types::String.new("hoge")})]

  a_reader_or_writer "should handle byte array fields",
                     "\x0a\x00\x03foo" \
                     "\x07\x00\x03bar\x00\x00\x00\x05\x01\x02\x03\x04\x05" \
                     "\x00",
                     [Tokens::TAG_Compound["foo", nil],
                      Tokens::TAG_Byte_Array["bar", "\x01\x02\x03\x04\x05"],
                      Tokens::TAG_End["", nil]],
                     ["foo",
                      Types::Compound.new({
                        "bar" => Types::ByteArray.new("\x01\x02\x03\x04\x05")})]

  a_reader_or_writer "should handle long fields",
                     "\x0a\x00\x03foo" \
                     "\x04\x00\x03bar\x01\x02\x03\x04\x05\x06\x07\x08" \
                     "\x00",
                     [Tokens::TAG_Compound["foo", nil],
                      Tokens::TAG_Long["bar", 0x0102030405060708],
                      Tokens::TAG_End["", nil]],
                     ["foo",
                      Types::Compound.new({
                        "bar" => Types::Long.new(0x0102030405060708)})]

  a_reader_or_writer "should handle float fields",
                     "\x0a\x00\x03foo" \
                     "\x05\x00\x03bar\x3f\xa0\x00\x00" \
                     "\x00",
                     [Tokens::TAG_Compound["foo", nil],
                      Tokens::TAG_Float["bar", "\x3f\xa0\x00\x00".unpack("g").first],
                      Tokens::TAG_End["", nil]],
                     ["foo",
                      Types::Compound.new({
                        "bar" => Types::Float.new("\x3f\xa0\x00\x00".unpack("g").first)})]

  a_reader_or_writer "should handle double fields",
                     "\x0a\x00\x03foo" \
                     "\x06\x00\x03bar\x3f\xf4\x00\x00\x00\x00\x00\x00" \
                     "\x00",
                     [Tokens::TAG_Compound["foo", nil],
                      Tokens::TAG_Double["bar", "\x3f\xf4\x00\x00\x00\x00\x00\x00".unpack("G").first],
                      Tokens::TAG_End["", nil]],
                     ["foo",
                      Types::Compound.new({
                        "bar" => Types::Double.new("\x3f\xf4\x00\x00\x00\x00\x00\x00".unpack("G").first)})]

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
                      Tokens::TAG_End["", nil]],
                     ["foo",
                      Types::Compound.new({
                        "bar" => Types::Compound.new({
                          "hoge" => Types::Byte.new(0x4e)})})]

  simple_list_types = [
    ["bytes", Types::Byte, Tokens::TAG_Byte, 0x01, lambda { |ns| ns.pack("C*") }],
    ["shorts", Types::Short, Tokens::TAG_Short, 0x02, lambda { |ns| ns.pack("n*") }],
    ["ints", Types::Int, Tokens::TAG_Int, 0x03, lambda { |ns| ns.pack("N*") }],
    ["longs", Types::Long, Tokens::TAG_Long, 0x04, lambda { |ns| ns.map { |n| [n].pack("x4N") }.join("") }],
    ["floats", Types::Float, Tokens::TAG_Float, 0x05, lambda { |ns| ns.pack("g*") }],
    ["doubles", Types::Double, Tokens::TAG_Double, 0x06, lambda { |ns| ns.pack("G*") }]
  ]

  for label, type, token, repr, pack in simple_list_types
    values = [9, 5]
    a_reader_or_writer "should handle lists of #{label}",
                       "\x0a\x00\x03foo" \
                       "\x09\x00\x03bar#{[repr].pack("C")}\x00\x00\x00\x02" \
                       "#{pack.call(values)}" \
                       "\x00",
                       [Tokens::TAG_Compound["foo", nil],
                        Tokens::TAG_List["bar", token],
                        token[0, values[0]],
                        token[1, values[1]],
                        Tokens::TAG_End[2, nil],
                        Tokens::TAG_End["", nil]],
                       ["foo",
                        Types::Compound.new({
                          "bar" =>
                            Types::List.new(type,
                                            values.map { |v| type.new(v) })})]
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
                      Tokens::TAG_End["", nil]],
                     ["foo",
                      Types::Compound.new({
                        "bar" => Types::List.new(Types::List, [
                          Types::List.new(Types::Byte,
                                          [Types::Byte.new(0x4a)])])})]
end

describe "NBTFile::tokenize" do
  include ZlibHelpers

  it_should_behave_like "readers and writers"

  def check_reader_or_writer(input, tokens, tree)
    io = make_zipped_stream(input)
    actual_tokens = []
    NBTFile.tokenize(io) do |token|
      actual_tokens << token
    end
    actual_tokens.should == tokens
  end
end

describe "NBTFile::tokenize_uncompressed" do
  it_should_behave_like "readers and writers"

  def check_reader_or_writer(input, tokens, tree)
    io = StringIO.new(input, "rb")
    actual_tokens = []
    NBTFile.tokenize_uncompressed(io) do |token|
      actual_tokens << token
    end
    actual_tokens.should == tokens
  end
end

describe "NBTFile::tokenize without a block" do
  include ZlibHelpers

  it_should_behave_like "readers and writers"

  def check_reader_or_writer(input, tokens, tree)
    io = make_zipped_stream(input)
    actual_tokens = NBTFile.tokenize(io)
    actual_tokens.should be_a_kind_of(Enumerable)
    actual_tokens.to_a.should == tokens
  end
end

describe "NBTFile::tokenize_uncompressed without a block" do
  include ZlibHelpers

  it_should_behave_like "readers and writers"

  def check_reader_or_writer(input, tokens, tree)
    io = StringIO.new(input)
    actual_tokens = NBTFile.tokenize_uncompressed(io)
    actual_tokens.should be_a_kind_of(Enumerable)
    actual_tokens.to_a.should == tokens
  end
end

describe "NBTFile::emit" do
  include ZlibHelpers

  it_should_behave_like "readers and writers"

  def check_reader_or_writer(output, tokens, tree)
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

  it "should convert strings to UTF-8 (on encoding-aware rubies)" do
    check_reader_or_writer "\x0a\x00\x03foo" \
                           "\x08\x00\x03bar\x00\x04hoge" \
                           "\x00",
                           [Tokens::TAG_Compound["foo", nil],
                            Tokens::TAG_String["bar", "hoge"._nbtfile_encode("UTF-16LE")],
                            Tokens::TAG_End["", nil]],
                           nil
  end

  it "should reject malformed UTF-8 strings" do
    io = StringIO.new
    NBTFile.emit(io) do |writer|
      writer.emit_compound("foo") do
        lambda {
          str = "hoge\xff"
          str._nbtfile_force_encoding("UTF-8")
          writer.emit_token(Tokens::TAG_String["bar", str])
        }.should raise_error(NBTFile::EncodingError)
      end
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

describe "NBTFile::read" do
  include ZlibHelpers
  it_should_behave_like "readers and writers"

  def check_reader_or_writer(input, tokens, tree)
    io = make_zipped_stream(input)
    actual_tree = NBTFile.read(io)
    actual_tree.should == tree
  end
end

describe "NBTFile::write" do
  include ZlibHelpers
  it_should_behave_like "readers and writers"

  def check_reader_or_writer(output, tokens, tree)
    io = StringIO.new()
    name, body = tree
    NBTFile.write(io, name, body)
    actual_output = unzip_string(io.string)
    actual_output.should == output
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

describe "NBTFile::transcode_to_yaml" do
  def self.nbtfile_transcode(description, tokens, result)
    it description do
      io = StringIO.new()
      NBTFile.emit(io) do |writer|
        for token in tokens
          writer.emit_token(token)
        end
      end
      out = StringIO.new()
      NBTFile.transcode_to_yaml(StringIO.new(io.string), out)
      actual_result = YAML.load(out.string)
      actual_result.should == result
    end
  end

  nbtfile_transcode "should transcode to YAML",
                    [Tokens::TAG_Compound["foo", nil],
                     Tokens::TAG_Byte["a", 19],
                     Tokens::TAG_Byte["b", 23],
                     Tokens::TAG_End[nil, nil]],
                    ["foo", {"a" => 19, "b" => 23}]
end
