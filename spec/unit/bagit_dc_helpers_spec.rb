require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require 'cul_scv_hydra'
describe BagIt::DcHelpers do
  DC_FIXTURE = <<-dc
  <oai_dc:dc
    xmlns:oai_dc='http://www.openarchives.org/OAI/2.0/oai_dc/'
    xmlns:dc='http://purl.org/dc/elements/1.1/'
    xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance'
    xsi:schemaLocation='http://www.openarchives.org/OAI/2.0/oai_dc/ http://www.openarchives.org/OAI/2.0/oai_dc.xsd'></oai_dc:dc>
dc
  class TestModel
    include BagIt::DcHelpers
    def datastreams
      @map ||= begin
        map = {'DC' => Cul::Scv::Hydra::Datastreams::DCMetadata.new}
        map['DC'].content= DC_FIXTURE
        map    
      end
    end
  end
  it "should add identifiers with #add_dc_identifier}" do
    test = TestModel.new
    test.add_dc_identifier 'lol:wut'
    test.datastreams['DC'].content.should =~ /lol\:wut/
    test.add_dc_identifier 'foo:bar'
    test.datastreams['DC'].content.should =~ /lol\:wut/
    test.datastreams['DC'].content.should =~ /foo\:bar/
    test.set_dc_identifier 'bar:baz'
    test.datastreams['DC'].content.should =~ /bar\:baz/
    test.datastreams['DC'].content.should_not =~ /lol\:wut/
  end
end
