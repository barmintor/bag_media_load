require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require 'cul_hydra'
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
        map = {'DC' => Cul::Hydra::Datastreams::DCMetadata.new}
        map['DC'].content= DC_FIXTURE
        map    
      end
    end
  end
  it "should add identifiers with #add_dc_identifier}" do
    test = TestModel.new
    dc = test.datastreams['DC']
    test.add_dc_identifier 'lol:wut'
    expect(dc.content).to match /lol\:wut/
    test.add_dc_identifier 'foo:bar'
    expect(dc.content).to match /lol\:wut/
    expect(dc.content).to match /foo\:bar/
    test.set_dc_identifier 'bar:baz'
    expect(dc.content).to match /bar\:baz/
    expect(dc.content).not_to match /foo\:bar/
  end
end
