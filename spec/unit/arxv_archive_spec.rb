require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
describe Arxv::Archive do
  let(:bag_path) {
    fixture('archivematica_bag/bag-info.txt')
  }
  let(:bag_info) {
    BagIt::Info.new(bag_path)
  }
  subject {
    bag_info.manifest('sha512')
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
      key = File.absolute_path(File.join(bag_info.bag_path,'data',"objects/SmartCane_1_.pdf"))
      entry = entries[key]
      expect(entry.mime).to eql("application/pdf")
      expect(entry.pronom_format).to eql("fmt/18")
      expect(entry.dc_type).to eql("PageDescription")
      expect(entry.local_id).to eql('content')
      expect(entry.original_path).to eql('SmartCane[1].pdf')
    end
    it "should group derivatives under the original file" do
      key = File.absolute_path(File.join(bag_info.bag_path,'data',"objects/SmartCane_1_.pdf"))
      entry = entries[key]
      expect(entry.derivatives.size).to eql(1)
      derivative = entry.derivatives.first
      deriv_path = File.absolute_path(File.join(bag_info.bag_path,'data',"objects/SmartCane_1_-81c418bc-7d2e-4dee-8a1e-9d1e75358ead.pdf"))
      expect(derivative.path).to eql deriv_path
      expect(derivative.original_path).to eql deriv_path
      expect(derivative.mime).to eql("application/pdf")
      expect(derivative.local_id).to eql 'file-81c418bc-7d2e-4dee-8a1e-9d1e75358ead'
    end
  end
  describe "#resources" do
    it "should create a resource for each entry" do
    end
  end
end