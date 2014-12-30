require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
describe BagIt::Info do
  before(:all) do
    class MockFile
      attr_accessor :path
      def initialize(path)
        @lines = []
        self.path = path
      end

      def each &block
        @lines.each &block
      end

      def << line
        @lines << line
      end
    end
  end

  describe "#id_schema" do
    before do
      @mock_file = MockFile.new('/foo/bar/bag-info.txt')
    end

    it "should correctly resolve relative paths up to the bag root" do
      test = BagIt::Info.new(fixture('schema_bag/bag-info.txt'))
      test.id_for('test').should == 'test_id'
    end

    it "should correctly resolve relative paths to the bag root" do
      test = BagIt::Info.new(fixture('schema_bag'))
      test.bag_path.split('/')[-1].should == 'schema_bag'
      test.id_for('test').should == 'test_id'
    end

    it "should work without a specified name parser" do
      test =BagIt::Info.new(fixture('no_schema_bag/bag-info.txt'))
      # the default is an APT-style ID
      test.id_for('test').should == 'apt://columbia.edu/foo/test'
    end
  end

  describe "#sidecar" do
    before do
      @mock_file = MockFile.new('/foo/bar/bag-info.txt')
    end

    it "should correctly resolve relative paths to the bag root" do
      test =BagIt::Info.new(fixture('schema_bag/bag-info.txt'))
      test.id_for('test').should == 'test_id'
    end
  end
end