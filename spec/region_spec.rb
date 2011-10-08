require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require 'nbtfile/region'
require 'fileutils'

describe NBTFile::RegionFile do
  before :each do
    @temp_dir = "tmp_regions"
    FileUtils.mkdir_p(@temp_dir)
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

  it "idempotently deletes chunks" do
    @region_file.delete_chunk(0, 0)
  end

  it "stores data in chunks" do
    content = "foobar"
    @region_file.store_chunk(0, 0, content)
    @region_file.get_chunk(0, 0).should == content
  end

  it "creates the file after a chunk has been stored" do
    content = "foobar"
    @region_file.store_chunk(0, 0, content)
    File.exists?(@region_filename).should be_true
  end

  it "removes the file only after the last chunk is deleted" do
    content = "foobar"
    @region_file.store_chunk(0, 0, content)
    @region_file.store_chunk(1, 0, content)
    @region_file.delete_chunk(0, 0)
    File.exists?(@region_filename).should be_true
    @region_file.delete_chunk(1, 0)
    File.exists?(@region_filename).should be_false
  end

  it "persists data in the file" do
    content = "foobar"
    @region_file.store_chunk(0, 0, content)
    region_file2 = NBTFile::RegionFile.new(@region_filename)
    region_file2.get_chunk(0, 0).should == content
  end

  it "recognizes the number of chunks stored" do
    content = "foobar"
    @region_file.store_chunk(0, 0, content)
    region_file2 = NBTFile::RegionFile.new(@region_filename)
    region_file2.store_chunk(1, 0, content)
    region_file2.delete_chunk(1, 0)
    File.exists?(@region_filename).should be_true
    region_file2.delete_chunk(0, 0)
    File.exists?(@region_filename).should be_false
  end

  it "can enumerate stored chunks" do
    content = "foobar"
    @region_file.store_chunk(0, 0, content)
    @region_file.store_chunk(1, 0, content)
    @region_file.store_chunk(0, 2, content)
    Set.new(@region_file.chunks).should == Set[[0, 0], [1, 0], [0, 2]]
  end
end
