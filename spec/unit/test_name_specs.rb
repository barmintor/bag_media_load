require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
describe "NameParser" do
	before(:all) do
  end

  it "should load the modules appropriately" do
    test = BagIt::NameParser.new(YAML.load(fixture("name_parsing_schema/p_c_numeric_basename.yml")))
  end
  describe " simple parent-child id parsing" do
    it "should parse ids from basename" do
      test = BagIt::NameParser.new(YAML.load(fixture("name_parsing_schema/p_c_numeric_basename.yml")))
      test.id("data/foo/ldpd_leh_12_34_56.tif").should == "ldpd_leh_12_34_56"
      test.parent("data/foo/ldpd_leh_12_34_56.tif").should == "ldpd_leh_12_34"
    end
  end

  describe " side parsing with an unexpected default" do
    it "should parse side from basename" do
      test = BagIt::NameParser.new(YAML.load(fixture("name_parsing_schema/p_c_numeric_basename.yml")))
      test.side("data/foo/ldpd_leh_12_34_56R.tif").should == 'R'
      test.side("data/foo/ldpd_leh_12_34_56V.tif").should == 'V'
    end
    it " parsing with an unexpected default side" do
      test = BagIt::NameParser.new(YAML.load(fixture("name_parsing_schema/p_c_numeric_basename.yml")))
      test.side("data/foo/ldpd_leh_12_34_56.tif").should == 'V'
    end
  end
  describe " parsing with literal-prefixed substitutions" do
    it "should parse ids from basename" do
      test = BagIt::NameParser.new(YAML.load(fixture("name_parsing_schema/prefixed_subs.yml")))
      test.id("data/foo/12_34.tif").should == "ldpd.treasures.12.34"
      test.id("data/foo/12.tif").should == "ldpd.treasures.12.000"
      test.parent("data/foo/12.tif").should == "ldpd.treasures.12"
    end
  end
end