require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
describe BagIt::Resource do
  before do
    class ResourceTest
      include BagIt::Resource
    end
    @test = ResourceTest.new
  end
  after do
    Object.send(:remove_const, :ResourceTest)
  end
  describe "#create_scaled_image" do
  	before :each do
  		@fixture = fixture_path("resources/CCITT_2.TIF")
      File.open(@fixture) do |blob|
        rels = Cul::Image::Properties.identify(blob)
        @src_width = rels['http://www.w3.org/2003/12/exif/ns#imageWidth'].to_i
        @src_length = rels['http://www.w3.org/2003/12/exif/ns#imageLength'].to_i
      end
  	end

  	it "should create derivatives of the right size and type" do
      actual = Tempfile.new(["temp",'.png'])
      ImageScience.with_image(@fixture) do |img|
          @test.create_scaled_image(img, 200, actual)
      end
      rels = {}
      File.open(actual.path) do |blob|
        rels = Cul::Image::Properties.identify(blob)
      end
      rels['http://www.w3.org/2003/12/exif/ns#imageLength'].should == '200'
      rels['http://www.w3.org/2003/12/exif/ns#imageWidth'].should == (( 200 * @src_width ) / @src_length).to_s
      rels['http://purl.org/dc/terms/format'].should == 'image/png'
  	end

  end
end