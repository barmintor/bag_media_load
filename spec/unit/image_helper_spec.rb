require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
describe "ImageHelpers" do
  before do
    class ImageHelpersTest
      include BagIt::ImageHelpers
    end
    @test = ImageHelpersTest.new
  end
  after do
    Object.send(:remove_const, :ImageHelpersTest)
  end
  describe ".levels_for" do
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
end