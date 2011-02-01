shared_examples_for "high-level types" do
  it "should include NBTFile::Types::Base" do
    @type.should < NBTFile::Types::Base
  end
end

INTEGER_TYPE_CASES = {
  NBTFile::Types::Byte => 8,
  NBTFile::Types::Short => 16,
  NBTFile::Types::Int => 32,
  NBTFile::Types::Long => 64
}

INTEGER_TYPE_CASES.each do |type, bits|
  range = (-2**(bits-1))..(2**(bits-1)-1)
  describe "#{type}" do
    it_should_behave_like "high-level types"

    before :all do
      @type = type
    end

    it "should reject values larger than #{range.end}" do
      lambda { type.new(range.end+1) }.should raise_error(RangeError)
    end

    it "should reject values smaller than #{range.begin}" do
      lambda { type.new(range.begin - 1) }.should raise_error(RangeError)
    end

    it "should accept integers" do
      type.new(1)
    end

    it "should have a value attribute" do
      type.new(42).value.should == 42
    end

    it "should reject non-integers" do
      lambda { type.new(0.5) }.should raise_error(TypeError)
    end

    it "should support #to_int" do
      type.new(3).to_int.should == 3
    end

    it "should support #to_i" do
      type.new(3).to_i.should == 3
    end

    it "should support equality by value" do
      type.new(3).should == 3
      type.new(3).should_not == 4
      type.new(3).should == type.new(3)
      type.new(3).should_not == type.new(4)
    end
  end
end

shared_examples_for "floating-point high-level types" do
  it "should accept Numerics" do
    @type.new(3.3)
    @type.new(3)
    @type.new(2**68)
  end

  it "should not accept non-numerics" do
    lambda { @type.new("3.3") }.should raise_error(TypeError)
  end

  it "should have a value attribute" do
    @type.new(3.3).value.should == 3.3
  end

  it "should support #to_f" do
    @type.new(3.3).to_f.should == 3.3
  end

  it "should support equality by value" do
    @type.new(3.3).should == 3.3
    @type.new(3.3).should_not == 4
    @type.new(3.3).should == @type.new(3.3)
    @type.new(3.3).should_not == @type.new(4)
  end
end

describe NBTFile::Types::Float do
  it_should_behave_like "high-level types"
  it_should_behave_like "floating-point high-level types"

  before :all do
    @type = NBTFile::Types::Float
  end
end

describe NBTFile::Types::Double do
  it_should_behave_like "high-level types"
  it_should_behave_like "floating-point high-level types"

  before :all do
    @type = NBTFile::Types::Double
  end
end

describe NBTFile::Types::String do
  it_should_behave_like "high-level types"

  before :all do
    @type = NBTFile::Types::String
  end

  it "should have a #value accessor" do
    NBTFile::Types::String.new("foo").value.should == "foo"
  end

  it "should support #to_s" do
    NBTFile::Types::String.new("foo").to_s.should == "foo"
  end
end

describe NBTFile::Types::ByteArray do
  it_should_behave_like "high-level types"

  before :all do
    @type = NBTFile::Types::ByteArray
  end

  it "should have a #value accessor" do
    NBTFile::Types::ByteArray.new("foo").value.should == "foo"
  end
end

describe NBTFile::Types::List do
  it_should_behave_like "high-level types"

  before :all do
    @type = NBTFile::Types::List
  end

  before :each do
    @instance = NBTFile::Types::List.new(NBTFile::Types::Int)
  end

  it "should accept instances of the given type" do
    @instance << NBTFile::Types::Int.new(3)
    @instance.length.should == 1
  end

  it "should reject instances of other types" do
    lambda {
      @instance << NBTFile::Types::Byte.new(3)
    }.should raise_error(TypeError)
    lambda {
      @instance << 3
    }.should raise_error(TypeError)
    lambda {
      @instance << nil
    }.should raise_error(TypeError)
    @instance.length.should == 0
  end

  it "should implement Enumerable" do
    NBTFile::Types::List.should < Enumerable
  end
end

describe NBTFile::Types::Compound do
  it_should_behave_like "high-level types"

  before :all do
    @type = NBTFile::Types::Compound
  end

  before :each do
    @instance = NBTFile::Types::Compound.new
  end

  it "should allow setting and retrieving a field" do
    @instance["foo"] = NBTFile::Types::Int.new(3)
    @instance["foo"].should == NBTFile::Types::Int.new(3)
  end

  it "should allow removing a field" do
    @instance["foo"] = NBTFile::Types::Int.new(3)
    @instance.delete "foo"
    @instance.delete "foo"
    @instance["foo"].should be_nil
  end

  it "should accept values deriving from NBTFile::Types::Base" do
    @instance["foo"] = NBTFile::Types::Int.new(3)
  end

  it "should reject values not deriving from NBTFile::Types::Base" do
    lambda { @instance["foo"] = 3 }.should raise_error(TypeError)
  end
end
