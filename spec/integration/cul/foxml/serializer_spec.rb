require File.expand_path(File.dirname(__FILE__) + '/../../../spec_helper')
require 'cul_foxml'

describe Cul::Foxml::Serializer, type: :integration do
  describe ".serialize_object" do
    let(:test_pid) { BagIt.next_pid }
    let(:repository) { Cul::Hydra::Fedora.repository }
    let(:new_object) { GenericResource.new(pid: test_pid) }
    let(:download_pred) { 'info:fedora/fedora-system:def/model#downloadFilename' }
    let(:download_name) { "dublin_core.xml" }
    let(:local_id) { 'local:identifier' }
    before do
      dc = new_object.datastreams['DC']
      rels_ext = new_object.datastreams['RELS-EXT']
      rels_ext.controlGroup = 'M'
      rels_ext.dsLabel = 'RDF Statements about this object'
      rels_ext.formatURI = "info:fedora/fedora-system:FedoraRELSExt-1.0"
      new_object.label = 'Example Title'
      new_object.state = 'A'
      new_object.set_dc_title(new_object.label)
      new_object.set_dc_contributor('Examples Inc.')
      new_object.set_dc_identifier(local_id)
      dc.controlGroup = 'M'
      dc.dsLabel = "Dublin Core Record for this object"
      dc.formatURI = "http://www.openarchives.org/OAI/2.0/oai_dc/"
      new_object.add_relationship(:has_model, GenericResource.to_class_uri)
      new_object.rels_int.mimeType = 'text/xml'
      new_object.rels_int.add_relationship(dc, download_pred, download_name, true)
      new_object.rels_int.add_relationship(rels_ext, :format_of, dc)
      io = StringIO.new
      Cul::Foxml::Serializer.serialize_object(new_object, io)
      repository.ingest(pid: test_pid, file: io.string)
    end

    subject { GenericResource.find(test_pid) }

    it 'assigns the correct controlGroups to datastreams' do
      expect(subject.datastreams['DC'].controlGroup).to eql 'M'
      expect(subject.datastreams['RELS-EXT'].controlGroup).to eql 'M'
    end

    it 'creates parseable relationship datastreams' do
      dc = subject.datastreams['DC']
      rels_ext = subject.datastreams['RELS-EXT']
      stmt = subject.rels_int.relationships(dc, download_pred).first
      expect(stmt.object.to_s).to eql download_name
      ids = dc.term_values(:dc_identifier)
      expect(ids).to include(local_id)
      expect(ids).to include(test_pid)
#      open('tmp/object.xml', 'w') { |b| b.write(repository.api.object_xml(pid: test_pid)) }
    end
  end
end