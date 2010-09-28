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

  def self.a_reader(desc, input, events)
    it desc do
      io = make_zipped_stream(input)
      reader = NBTFile::Reader.new(io)
      actual_events = []
      reader.each_event do |event|
        actual_events << event
      end
      actual_events.should == events
    end
  end

  a_reader "should parse basic documents",
           "\x0a\x00\x03foo" \
           "\x00",
           [[:tag_compound, "foo"],
            [:tag_end]]

  a_reader "should parse integer fields",
           "\x0a\x00\x03foo" \
           "\x04\x00\x03bar\x01\x02\x03\x04" \
           "\x00",
           [[:tag_compound, "foo"],
            [:tag_int, "bar", 0x01020304],
            [:tag_end]]
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
