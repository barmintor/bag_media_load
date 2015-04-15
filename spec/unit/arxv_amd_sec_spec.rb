require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
describe Arxv::AmdSec do
  let(:node) { Nokogiri::XML(fixture(npath).read).css('amdSec').first}
  subject { Arxv::AmdSec.new(node)}
  context "with a straightforward PUID" do
    let(:npath) { 'amd_sec/fmt_40.xml' }
    it do
      expect(subject.puid).to eql('fmt/40')
      expect(subject.mime_type).to eql('application/msword')
    end
  end
  context "with a OLE2 PUID" do
    let(:npath) { 'amd_sec/fmt_111.xml' }
    it do
      expect(subject.puid).to eql('fmt/40')
      expect(subject.mime_type).to eql('application/msword')
    end
  end
  context "with a OOXML PUID" do
    let(:npath) { 'amd_sec/fmt_189.xml' }
    it do
      expect(subject.puid).to eql('fmt/412')
      expect(subject.mime_type).to eql('application/msword')
    end
  end
end
