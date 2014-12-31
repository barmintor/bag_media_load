require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
describe BagMediaLoad::DsPathHelpers do
  before(:all) do
    class TestRig
      include BagMediaLoad::DsPathHelpers
    end
  end
  after(:all) do
    Object.send(:remove_const, :TestRig)
  end
  subject { TestRig.new }
  let(:moomin_path) { File.join('','Moomin\'s Dream','#index.html') }
  let(:moomin_uri) { "file:/Moomin's%20Dream/%23index.html" }
  let(:http_uri) {"http://www.moomin.com/index.html"}
  it "should escape file paths" do
    expect(subject.path_to_ds_uri(moomin_path)).to eql moomin_uri
  end
  it "should unescape file URIs" do
    expect(subject.ds_uri_to_path(moomin_uri)).to eql moomin_path
  end
  it "should leave non-file URIs alone" do
    expect(subject.ds_uri_to_path(http_uri)).to eql http_uri
  end
end