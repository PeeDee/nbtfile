require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require 'nbtfile'
require 'stringio'
require 'zlib'

describe NBTFile::Reader do
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
           [[:tag_compound, "foo", nil],
            [:tag_end, "", nil]]

  a_reader "should parse integer fields",
           "\x0a\x00\x03foo" \
           "\x03\x00\x03bar\x01\x02\x03\x04" \
           "\x00",
           [[:tag_compound, "foo", nil],
            [:tag_int, "bar", 0x01020304],
            [:tag_end, "", nil]]

  a_reader "should parse byte fields",
           "\x0a\x00\x03foo" \
           "\x01\x00\x03bar\x4e" \
           "\x00",
           [[:tag_compound, "foo", nil],
            [:tag_byte, "bar", 0x4e],
            [:tag_end, "", nil]]

  a_reader "should parse string fields",
           "\x0a\x00\x03foo" \
           "\x08\x00\x03bar\x00\x04hoge" \
           "\x00",
           [[:tag_compound, "foo", nil],
            [:tag_string, "bar", "hoge"],
            [:tag_end, "", nil]]

  a_reader "should parse byte array fields",
           "\x0a\x00\x03foo" \
           "\x07\x00\x03bar\x00\x00\x00\x05\x01\x02\x03\x04\x05" \
           "\x00",
           [[:tag_compound, "foo", nil],
            [:tag_byte_array, "bar", "\x01\x02\x03\x04\x05"],
            [:tag_end, "", nil]]

  a_reader "should parse long fields",
           "\x0a\x00\x03foo" \
           "\x04\x00\x03bar\x01\x02\x03\x04\x05\x06\x07\x08" \
           "\x00",
           [[:tag_compound, "foo", nil],
            [:tag_long, "bar", 0x0102030405060708],
            [:tag_end, "", nil]]

  a_reader "should parse float fields",
           "\x0a\x00\x03foo" \
           "\x05\x00\x03bar\x3f\xa0\x00\x00" \
           "\x00",
           [[:tag_compound, "foo", nil],
            [:tag_float, "bar", "\x3f\xa0\x00\x00".unpack("g").first],
            [:tag_end, "", nil]]

  a_reader "should parse double fields",
           "\x0a\x00\x03foo" \
           "\x06\x00\x03bar\x3f\xf4\x00\x00\x00\x00\x00\x00" \
           "\x00",
           [[:tag_compound, "foo", nil],
            [:tag_double, "bar", "\x3f\xf4\x00\x00\x00\x00\x00\x00".unpack("G").first],
            [:tag_end, "", nil]]

  a_reader "should parse nested compound fields",
           "\x0a\x00\x03foo" \
           "\x0a\x00\x03bar" \
           "\x01\x00\x04hoge\x4e" \
           "\x00" \
           "\x00",
           [[:tag_compound, "foo", nil],
            [:tag_compound, "bar", nil],
            [:tag_byte, "hoge", 0x4e],
            [:tag_end, "", nil],
            [:tag_end, "", nil]]

  a_reader "should parse list of simple type",
           "\x0a\x00\x03foo" \
           "\x09\x00\x03bar\x01\x00\x00\x00\x02" \
           "\x7f" \
           "\x3a" \
           "\x00",
           [[:tag_compound, "foo", nil],
            [:tag_list, "bar", :tag_byte],
            [:tag_byte, nil, 0x7f],
            [:tag_byte, nil, 0x3a],
            [:tag_end, nil, nil],
            [:tag_end, "", nil]] 
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
