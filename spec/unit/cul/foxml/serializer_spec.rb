require File.expand_path(File.dirname(__FILE__) + '/../../../spec_helper')
require 'cul_foxml'

describe Cul::Foxml::Serializer do
  describe ".serialize_object_properties" do
    let(:af_object) { instance_double(ActiveFedora::Base) }
    before do
      allow(af_object).to receive(:pid).and_return('example:1')
      allow(af_object).to receive(:label).and_return('Example Title')
    end
    subject do
      io = StringIO.new
      Cul::Foxml::Serializer.serialize_object_properties(af_object, io)
      io.string
    end
    context "is active" do
      let(:xml) { fixture('foxml/object_properties/active.xml').read }
      before { allow(af_object).to receive(:state).and_return('A') }
      it { is_expected.to eql(xml) }
    end
  end

  describe ".serialize_object" do
    let(:af_object) { instance_double(ActiveFedora::Base) }
    before do
      allow(af_object).to receive(:pid).and_return('example:1')
      allow(af_object).to receive(:label).and_return('Example Title')
      allow(af_object).to receive(:datastreams).and_return({})
      allow(af_object).to receive(:object_relations).and_return({})
      expect(af_object).to receive(:assert_content_model)
    end
    subject do
      io = StringIO.new
      Cul::Foxml::Serializer.serialize_object(af_object, io) {}
      io.string
    end
    context "is active" do
      let(:xml) { fixture('foxml/object/active.xml').read }
      before { allow(af_object).to receive(:state).and_return('A') }
      it { is_expected.to eql(xml) }
    end
  end

  describe ".serialize_datastream" do
    let(:af_datastream) { instance_double(ActiveFedora::Datastream) }
    before do
      allow(af_datastream).to receive(:dsid).and_return('EXAMPLE-DS')
      allow(af_datastream).to receive(:controlGroup).and_return('M')
      allow(af_datastream).to receive(:versionable).and_return(false)
    end
    subject do
      io = StringIO.new
      Cul::Foxml::Serializer.serialize_datastream(af_datastream, io) {}
      io.string
    end
    context "is active" do
      let(:xml) { fixture('foxml/datastream/active.xml').read }
      before { allow(af_datastream).to receive(:state).and_return('A') }
      it { is_expected.to eql(xml) }
    end
  end

  describe ".serialize_datastream_version" do
    let(:af_datastream) { instance_double(ActiveFedora::Datastream) }
    before do
      allow(af_datastream).to receive(:dsid).and_return('EXAMPLE-DS')
      allow(af_datastream).to receive(:dsLabel).and_return('Example Datastream Version')
      allow(af_datastream).to receive(:formatURI).and_return('http://example.org/xml')
      allow(af_datastream).to receive(:mimeType).and_return('text/xml')
    end
    subject do
      io = StringIO.new
      Cul::Foxml::Serializer.serialize_datastream_version(af_datastream, io)
      io.string
    end

    context "with inlined xml content" do
      let(:xml) { fixture('foxml/datastream/versions/xml-content.xml').read }
      before do
        allow(af_datastream).to receive(:dsLocation).and_return(nil)
        allow(af_datastream).to receive(:controlGroup).and_return("X")
        allow(af_datastream).to receive(:content).and_return("\n<elements></elements>\n")
        allow(af_datastream).to receive(:changed_attributes).and_return('content' => nil)
      end
      it { is_expected.to eql(xml) }
    end

    context "with referenced content" do
      let(:xml) { fixture('foxml/datastream/versions/content-location.xml').read }
      before do
        allow(af_datastream).to receive(:dsLocation).and_return("http://example.org/content")
        allow(af_datastream).to receive(:controlGroup).and_return("E")
        allow(af_datastream).to receive(:content).and_return(nil)
        allow(af_datastream).to receive(:changed_attributes).and_return('dsLocation' => nil)
      end
      it { is_expected.to eql(xml) }
    end
  end
end
