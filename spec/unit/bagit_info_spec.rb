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
  let(:no_schema_bag) { BagIt::Info.new(fixture('no_schema_bag/bag-info.txt')) }
  let(:schema_bag){ BagIt::Info.new(fixture('schema_bag/bag-info.txt')) }
  let(:archivematica_bag){ BagIt::Info.new(fixture('archivematica_bag/bag-info.txt')) }
  describe "#id_schema" do
    before do
      @mock_file = MockFile.new('/foo/bar/bag-info.txt')
    end
    it "should correctly resolve relative paths up to the bag root" do
      expect(schema_bag.id_for('test')).to eql 'test_id'
    end

    it "should correctly resolve relative paths to the bag root" do
      test = BagIt::Info.new(fixture('schema_bag'))
      expect(test.bag_path.split('/')[-1]).to eql 'schema_bag'
      expect(test.id_for('test')).to eql 'test_id'
    end

    it "should work without a specified name parser" do
      # the default is an APT-style ID
      expect(no_schema_bag.id_for('test')).to eql 'apt://columbia.edu/foo/test'
    end
  end
  describe "#manifest_path" do
    it "should default to md5" do
      expect(File.basename(schema_bag.manifest_path)).to eql "manifest-md5.txt"
    end
    it "should allow parameterized algorithms" do
      expect(File.basename(schema_bag.manifest_path('foo'))).to eql "manifest-foo.txt"
    end
  end
  describe "#manifest" do
    it "should use a generic manifest with a generic bag" do
      expect(schema_bag.manifest.class).to eql BagIt::Manifest
      expect(no_schema_bag.manifest.class).to eql BagIt::Manifest
    end
    it "should use a arxv manifest with a arxv bag" do
      expect(archivematica_bag.manifest).to be_a Arxv::Archive
    end
  end
  describe "#sidecar" do
    before do
      @mock_file = MockFile.new('/foo/bar/bag-info.txt')
    end

    it "should correctly resolve relative paths to the bag root" do
      expect(schema_bag.id_for('test')).to eql 'test_id'
    end
  end
  describe '#structure' do
    it "should generate the right structMetadata for standard bags" do
      io = StringIO.new
      archivematica_bag.structure('sha512',nil,io)
      io.rewind
      expected = open(fixture('structMetadata/archivematica_bag.xml')) {|f| f.read}
      actual = io.read
      expect(expected).to eql(actual)
    end
    it "should generate the right structMetadata for archivematica bags" do
      io = StringIO.new
      no_schema_bag.structure('sha1',nil,io)
      io.rewind
      expected = open(fixture('structMetadata/no_schema_bag.xml')) {|f| f.read}
      actual = io.read
      expect(expected).to eql(actual)
    end
  end
end