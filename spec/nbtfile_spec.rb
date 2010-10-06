require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require 'nbtfile'
require 'stringio'
require 'zlib'

describe NBTFile::Reader do
  Types = NBTFile::Types

  def make_zipped_stream(data)
    gz = Zlib::GzipWriter.new(StringIO.new())
    gz << data
    string = gz.close.string
    StringIO.new(string, "rb")
  end

  def self.a_reader(desc, input, tags)
    it desc do
      io = make_zipped_stream(input)
      reader = NBTFile::Reader.new(io)
      actual_tags = []
      reader.each_tag do |tag|
        actual_tags << tag
      end
      actual_tags.should == tags
    end
  end

  a_reader "should parse basic documents",
           "\x0a\x00\x03foo" \
           "\x00",
           [[Types::TAG_Compound, "foo", nil],
            [Types::TAG_End, "", nil]]

  a_reader "should parse integers as signed",
           "\x0a\x00\x03foo" \
           "\x03\x00\x03bar\xff\xff\xff\xfe" \
           "\x00",
           [[Types::TAG_Compound, "foo", nil],
            [Types::TAG_Int, "bar", -2],
            [Types::TAG_End, "", nil]]

  a_reader "should parse integer fields",
           "\x0a\x00\x03foo" \
           "\x03\x00\x03bar\x01\x02\x03\x04" \
           "\x00",
           [[Types::TAG_Compound, "foo", nil],
            [Types::TAG_Int, "bar", 0x01020304],
            [Types::TAG_End, "", nil]]

  a_reader "should parse short fields",
           "\x0a\x00\x03foo" \
           "\x02\x00\x03bar\x4e\x5a" \
           "\x00",
           [[Types::TAG_Compound, "foo", nil],
            [Types::TAG_Short, "bar", 0x4e5a],
            [Types::TAG_End, "", nil]]

  a_reader "should parse byte fields",
           "\x0a\x00\x03foo" \
           "\x01\x00\x03bar\x4e" \
           "\x00",
           [[Types::TAG_Compound, "foo", nil],
            [Types::TAG_Byte, "bar", 0x4e],
            [Types::TAG_End, "", nil]]

  a_reader "should parse string fields",
           "\x0a\x00\x03foo" \
           "\x08\x00\x03bar\x00\x04hoge" \
           "\x00",
           [[Types::TAG_Compound, "foo", nil],
            [Types::TAG_String, "bar", "hoge"],
            [Types::TAG_End, "", nil]]

  a_reader "should parse byte array fields",
           "\x0a\x00\x03foo" \
           "\x07\x00\x03bar\x00\x00\x00\x05\x01\x02\x03\x04\x05" \
           "\x00",
           [[Types::TAG_Compound, "foo", nil],
            [Types::TAG_Byte_Array, "bar", "\x01\x02\x03\x04\x05"],
            [Types::TAG_End, "", nil]]

  a_reader "should parse long fields",
           "\x0a\x00\x03foo" \
           "\x04\x00\x03bar\x01\x02\x03\x04\x05\x06\x07\x08" \
           "\x00",
           [[Types::TAG_Compound, "foo", nil],
            [Types::TAG_Long, "bar", 0x0102030405060708],
            [Types::TAG_End, "", nil]]

  a_reader "should parse float fields",
           "\x0a\x00\x03foo" \
           "\x05\x00\x03bar\x3f\xa0\x00\x00" \
           "\x00",
           [[Types::TAG_Compound, "foo", nil],
            [Types::TAG_Float, "bar", "\x3f\xa0\x00\x00".unpack("g").first],
            [Types::TAG_End, "", nil]]

  a_reader "should parse double fields",
           "\x0a\x00\x03foo" \
           "\x06\x00\x03bar\x3f\xf4\x00\x00\x00\x00\x00\x00" \
           "\x00",
           [[Types::TAG_Compound, "foo", nil],
            [Types::TAG_Double, "bar", "\x3f\xf4\x00\x00\x00\x00\x00\x00".unpack("G").first],
            [Types::TAG_End, "", nil]]

  a_reader "should parse nested compound fields",
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

  a_reader "should parse list of simple type",
           "\x0a\x00\x03foo" \
           "\x09\x00\x03bar\x01\x00\x00\x00\x02" \
           "\x7f" \
           "\x3a" \
           "\x00",
           [[Types::TAG_Compound, "foo", nil],
            [Types::TAG_List, "bar", Types::TAG_Byte],
            [Types::TAG_Byte, 0, 0x7f],
            [Types::TAG_Byte, 1, 0x3a],
            [Types::TAG_End, 2, nil],
            [Types::TAG_End, "", nil]] 

  a_reader "should parse nested lists",
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

describe NBTFile::Writer do
  def unzip_stream(io)
    gz = Zlib::GzipReader.new(io)
    begin
      gz.read
    ensure
      gz.close
    end
  end
end
