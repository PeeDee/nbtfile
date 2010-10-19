require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require 'enumerator'
require 'nbtfile'
require 'stringio'
require 'zlib'

shared_examples_for "readers and writers" do
  Types = NBTFile::Types

  def self.a_reader_or_writer(desc, serialized, tags)
    it desc do
      check_reader_or_writer(serialized, tags)
    end
  end

  a_reader_or_writer "should handle basic documents",
                     "\x0a\x00\x03foo" \
                     "\x00",
                     [[Types::TAG_Compound, "foo", nil],
                      [Types::TAG_End, "", nil]]

  a_reader_or_writer "should treat integers as signed",
                     "\x0a\x00\x03foo" \
                     "\x03\x00\x03bar\xff\xff\xff\xfe" \
                     "\x00",
                     [[Types::TAG_Compound, "foo", nil],
                      [Types::TAG_Int, "bar", -2],
                      [Types::TAG_End, "", nil]]

  a_reader_or_writer "should handle integer fields",
                     "\x0a\x00\x03foo" \
                     "\x03\x00\x03bar\x01\x02\x03\x04" \
                     "\x00",
                     [[Types::TAG_Compound, "foo", nil],
                      [Types::TAG_Int, "bar", 0x01020304],
                      [Types::TAG_End, "", nil]]

  a_reader_or_writer "should handle short fields",
                     "\x0a\x00\x03foo" \
                     "\x02\x00\x03bar\x4e\x5a" \
                     "\x00",
                     [[Types::TAG_Compound, "foo", nil],
                      [Types::TAG_Short, "bar", 0x4e5a],
                      [Types::TAG_End, "", nil]]

  a_reader_or_writer "should handle byte fields",
                     "\x0a\x00\x03foo" \
                     "\x01\x00\x03bar\x4e" \
                     "\x00",
                     [[Types::TAG_Compound, "foo", nil],
                      [Types::TAG_Byte, "bar", 0x4e],
                      [Types::TAG_End, "", nil]]

  a_reader_or_writer "should handle string fields",
                     "\x0a\x00\x03foo" \
                     "\x08\x00\x03bar\x00\x04hoge" \
                     "\x00",
                     [[Types::TAG_Compound, "foo", nil],
                      [Types::TAG_String, "bar", "hoge"],
                      [Types::TAG_End, "", nil]]

  a_reader_or_writer "should handle byte array fields",
                     "\x0a\x00\x03foo" \
                     "\x07\x00\x03bar\x00\x00\x00\x05\x01\x02\x03\x04\x05" \
                     "\x00",
                     [[Types::TAG_Compound, "foo", nil],
                      [Types::TAG_Byte_Array, "bar", "\x01\x02\x03\x04\x05"],
                      [Types::TAG_End, "", nil]]

  a_reader_or_writer "should handle long fields",
                     "\x0a\x00\x03foo" \
                     "\x04\x00\x03bar\x01\x02\x03\x04\x05\x06\x07\x08" \
                     "\x00",
                     [[Types::TAG_Compound, "foo", nil],
                      [Types::TAG_Long, "bar", 0x0102030405060708],
                      [Types::TAG_End, "", nil]]

  a_reader_or_writer "should handle float fields",
                     "\x0a\x00\x03foo" \
                     "\x05\x00\x03bar\x3f\xa0\x00\x00" \
                     "\x00",
                     [[Types::TAG_Compound, "foo", nil],
                      [Types::TAG_Float, "bar", "\x3f\xa0\x00\x00".unpack("g").first],
                      [Types::TAG_End, "", nil]]

  a_reader_or_writer "should handle double fields",
                     "\x0a\x00\x03foo" \
                     "\x06\x00\x03bar\x3f\xf4\x00\x00\x00\x00\x00\x00" \
                     "\x00",
                     [[Types::TAG_Compound, "foo", nil],
                      [Types::TAG_Double, "bar", "\x3f\xf4\x00\x00\x00\x00\x00\x00".unpack("G").first],
                      [Types::TAG_End, "", nil]]

  a_reader_or_writer "should handle nested compound fields",
                     "\x0a\x00\x03foo" \
                     "\x0a\x00\x03bar" \
                     "\x01\x00\x04hoge\x4e" \
                     "\x00" \
                     "\x00",
                     [[Types::TAG_Compound, "foo", nil],
                      [Types::TAG_Compound, "bar", nil],
                      [Types::TAG_Byte, "hoge", 0x4e],
                      [Types::TAG_End, "", nil],
                      [Types::TAG_End, "", nil]]

  simple_list_types = [
    ["bytes", Types::TAG_Byte, 0x01, lambda { |ns| ns.pack("C*") }],
    ["shorts", Types::TAG_Short, 0x02, lambda { |ns| ns.pack("n*") }],
    ["ints", Types::TAG_Int, 0x03, lambda { |ns| ns.pack("N*") }],
    ["longs", Types::TAG_Long, 0x04, lambda { |ns| ns.map { |n| [n].pack("x4N") }.join("") }],
    ["floats", Types::TAG_Float, 0x05, lambda { |ns| ns.pack("g*") }],
    ["doubles", Types::TAG_Double, 0x06, lambda { |ns| ns.pack("G*") }]
  ]

  for label, type, tag, pack in simple_list_types
    values = [9, 5]
    a_reader_or_writer "should handle lists of #{label}",
                       "\x0a\x00\x03foo" \
                       "\x09\x00\x03bar#{[tag].pack("C")}\x00\x00\x00\x02" \
                       "#{pack.call(values)}" \
                       "\x00",
                       [[Types::TAG_Compound, "foo", nil],
                        [Types::TAG_List, "bar", type],
                        [type, 0, values[0]],
                        [type, 1, values[1]],
                        [Types::TAG_End, 2, nil],
                      [Types::TAG_End, "", nil]] 
  end

  a_reader_or_writer "should handle nested lists",
                     "\x0a\x00\x03foo" \
                     "\x09\x00\x03bar\x09\x00\x00\x00\x01" \
                     "\x01\x00\x00\x00\x01" \
                     "\x4a" \
                     "\x00",
                     [[Types::TAG_Compound, "foo", nil],
                      [Types::TAG_List, "bar", Types::TAG_List],
                      [Types::TAG_List, 0, Types::TAG_Byte],
                      [Types::TAG_Byte, 0, 0x4a],
                      [Types::TAG_End, 1, nil],
                      [Types::TAG_End, 1, nil],
                      [Types::TAG_End, "", nil]]
end

describe NBTFile::Reader do
  include ZlibHelpers

  it_should_behave_like "readers and writers"

  def check_reader_or_writer(input, tags)
    io = make_zipped_stream(input)
    reader = NBTFile::Reader.new(io)
    actual_tags = []
    reader.each_tag do |tag|
      actual_tags << tag
    end
    actual_tags.should == tags
  end
end

describe NBTFile::Writer do
  include ZlibHelpers
  it_should_behave_like "readers and writers"

  def unzip_string(string)
    gz = Zlib::GzipReader.new(StringIO.new(string))
    begin
      gz.read
    ensure
      gz.close
    end
  end

  def check_reader_or_writer(output, tags)
    stream = StringIO.new()
    writer = NBTFile::Writer.new(stream)
    begin
      for tag in tags
        writer.emit_tag(*tag)
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
      writer.emit_tag(Types::TAG_Compound, "test", nil)
      writer.emit_list(Types::TAG_Byte, "foo") do
        writer.emit_item(12)
        writer.emit_item(43)
      end
      writer.emit_tag(Types::TAG_End, nil, nil)
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
      writer.emit_tag(Types::TAG_Compound, "test", nil)
      writer.emit_compound("xyz") do
        writer.emit_tag(Types::TAG_Byte, "foo", 0x08)
        writer.emit_tag(Types::TAG_Byte, "bar", 0x02)
      end
      writer.emit_tag(Types::TAG_End, nil, nil)
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
