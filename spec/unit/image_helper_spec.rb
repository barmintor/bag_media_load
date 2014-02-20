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
end