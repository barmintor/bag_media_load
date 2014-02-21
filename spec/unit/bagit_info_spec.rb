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

    it "should correctly resolve relative paths to the bag root" do
      test =BagIt::Info.new(fixture('test_bag/bag-info.txt'))
      test.id_schema.id('test').should == 'test_id'
    end
  end

end