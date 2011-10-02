require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require 'nbtfile/region'
require 'fileutils'

describe NBTFile::RegionFile do
  before :each do
    @temp_dir = "tmp_regions"
    @region_filename = File.join(@temp_dir, "region.mcr")
    @region_file = NBTFile::RegionFile.new(@region_filename)
  end

  after :each do
    FileUtils.rm_rf(@temp_dir)
  end

  it "does not immediately create an empty file" do
    File.exists?(@region_filename).should be_false
  end

  it "returns nil for non-existent chunks" do
    @region_file.get_chunk(0, 0).should be_nil
  end
end
