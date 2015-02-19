require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
describe "ImageHelpers" do
  before do
    class ImageHelpersTest
      include BagIt::ImageHelpers
    end
  end
  let(:test) { ImageHelpersTest.new}
  it 'should do minimal expected processing' do
    props = GenericResource.image_properties(path_to_fixture('resources/CCITT_2.TIF'))
    expect(props.size).to eql(4)
    expect(props[:image_length]).to eql(2376)
    expect(props[:image_width]).to eql(1728)
    expect(props[:extent]).to eql(11082)
    expect(props[:format]).to eql('image/tiff')
  end
  after do
    Object.send(:remove_const, :ImageHelpersTest)
  end
end