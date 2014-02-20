require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
describe BagIt::Resource do
  before :all do
    class ResourceTest
      include BagIt::Resource
    end
    @test = ResourceTest.new
    @fixture = fixture_path("resources/CCITT_2.TIF")
  end
  after :all do
    Object.send(:remove_const, :ResourceTest)
  end
  describe "#create_scaled_image" do
  	before :each do
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

  describe "#levels_for" do
    it "should calculate resolution levels correctly given an inherited set of known values" do
      known_values = { 
        96 => 0,
        192 => 1,
        384 => 2,
        768 => 3,
        1536 => 4,
        3072 => 5,
        6144 => 6
      }
      #known_values = {96 => 0, 192 => 1, 384 => 2, 768 => 3, 1536 => 4}
      known_values.each do |x, y|
        vals = [y,y,(y.zero? ? 0 : y - 1)]
        @test.levels_for(x).should be(vals[0]), "f(#{x}) shoud be #{vals[0]} was #{@test.levels_for(x)}"
        @test.levels_for(x + 1).should be(vals[1]), "f(#{x+1}) shoud be #{vals[1]} was #{@test.levels_for(x+1)}"
        @test.levels_for(x - 1 ).should be(vals[2]), "f(#{x-1}) shoud be #{vals[2]} was #{@test.levels_for(x-1)}"
      end
    end
  end

  describe '#convert_to_jp2' do
    it "should do this thing" do
      jp2 = @test.convert_to_jp2(@fixture)
      jp2.path.should =~ /\.jp2$/
    end
  end
end