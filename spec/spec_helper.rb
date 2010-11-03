$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'nbtfile'
require 'rspec'

module ZlibHelpers
  def make_zipped_stream(data)
    gz = Zlib::GzipWriter.new(StringIO.new())
    gz << data
    string = gz.close.string
    string._nbtfile_force_encoding("BINARY")
    StringIO.new(string, "rb")
  end

  def unzip_string(string)
    gz = Zlib::GzipReader.new(StringIO.new(string))
    begin
      data = gz.read
      data._nbtfile_force_encoding("BINARY")
      data
    ensure
      gz.close
    end
  end
end
