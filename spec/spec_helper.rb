$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'nbtfile'
require 'spec'
require 'spec/autorun'

Spec::Runner.configure do |config|
  
end

module ZlibHelpers

  def make_zipped_stream(data)
    gz = Zlib::GzipWriter.new(StringIO.new())
    gz << data
    string = gz.close.string
    StringIO.new(string, "rb")
  end

  def unzip_string(string)
    gz = Zlib::GzipReader.new(StringIO.new(string))
    begin
      gz.read
    ensure
      gz.close
    end
  end
end
