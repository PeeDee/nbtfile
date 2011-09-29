require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require 'nbtfile'
require 'stringio'
require 'digest/sha1'
require 'zlib'

describe NBTFile do
  include ZlibHelpers

  sample_pattern = File.join(File.dirname(__FILE__), '..', 'samples', '*.nbt')

  def perform_and_check_roundtrip(file)
    input = StringIO.new(File.read(file))
    output = StringIO.new()
    yield input, output
    input_bytes = unzip_string(input.string)
    output_bytes = unzip_string(output.string)

    input_digest = Digest::SHA1.hexdigest(input_bytes)
    output_digest = Digest::SHA1.hexdigest(output_bytes)

    output_digest.should == input_digest
  end

  def self.check_file(file)
    basename = File.basename(file)

    it "should roundtrip #{basename} at the token level" do
      perform_and_check_roundtrip(file) do |input, output|
        NBTFile.emit(output) do |emitter|
          NBTFile.tokenize(input) do |token|
            emitter.emit_token(token)
          end
        end
      end
    end

    it "should roundtrip #{basename} at the data model level" do
      perform_and_check_roundtrip(file) do |input, output|
        name, body = NBTFile.read(input)
        NBTFile.write(output, name, body)
      end
    end
  end

  for file in Dir.glob(sample_pattern)
    check_file(file)
  end
end
