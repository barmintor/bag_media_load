require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
describe Arxv::Archive do
  subject {
    Arxv::Archive.new
  }
  describe "#initialize" do
    it "should initialize with no arguments" do
      expect(subject).to be_a Object
    end
  end
  describe "#entries" do
    it "should collect original file entries" do
    end
    it "should group derivatives under the original file" do
    end
  end
  describe "#resources" do
    it "should create a resource for each entry" do
    end
  end
end