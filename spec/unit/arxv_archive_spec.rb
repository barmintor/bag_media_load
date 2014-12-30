require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
describe Arxv::Archive do
  let(:bag_path) {
    fixture('archivematica_bag/bag-info.txt')
  }
  subject {
    Arxv::Archive.new(BagIt::Info.new(bag_path))
  }
  describe "#initialize" do
    it "should initialize with no arguments" do
      expect(subject).to be_a Object
    end
  end
  describe "#entries" do
    let(:entries) {
      entries = {}
      subject.entries.each {|entry| entries[entry.path] = entry}
      entries
    }
    it "should collect original file entries" do
      expect(subject.entries).to be_truthy
      expect(entries.size).to eql(7)
    end
    it "should collect entry information from amdSec" do
      entry = entries["objects/SmartCane_1_.pdf"]
      expect(entry.mime).to eql("application/pdf")
    end
    it "should group derivatives under the original file" do
      entry = entries["objects/SmartCane_1_.pdf"]
      expect(entry.derivatives.size).to eql(1)
      derivative = entry.derivatives.first
      expect(derivative.path).to eql "objects/SmartCane_1_-81c418bc-7d2e-4dee-8a1e-9d1e75358ead.pdf"
      expect(derivative.mime).to be_nil
    end
  end
  describe "#resources" do
    it "should create a resource for each entry" do
    end
  end
end