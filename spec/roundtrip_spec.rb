require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require 'nbtfile'
require 'stringio'
require 'digest/sha1'
require 'zlib'

describe NBTFile do
  include ZlibHelpers

  sample_pattern = File.join(File.dirname(__FILE__), '..', 'samples', '*.nbt')

  def self.check_file(file)
    it "should roundtrip #{File.basename(file)}" do
      input = StringIO.new(File.read(file))
      output = StringIO.new()

      reader = NBTFile::Reader.new(input)
      writer = NBTFile::Writer.new(output)
      begin
        reader.each_token do |token|
          writer.emit_token(token)
        end
      ensure
        writer.finish
      end

      input_bytes = unzip_string(input.string)
      output_bytes = unzip_string(output.string)

      input_digest = Digest::SHA1.hexdigest(input_bytes)
      output_digest = Digest::SHA1.hexdigest(output_bytes)

      output_digest.should == input_digest
    end
  end

  for file in Dir.glob(sample_pattern)
    check_file(file)
  end
end
