require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
describe BagIt::NameParser do
	before(:all) do
  end

  it "should load the modules appropriately" do
    test = BagIt::NameParser.new(YAML.load(fixture("name_parsing_schema/p_c_numeric_basename.yml")))
  end
  describe " simple parent-child id parsing" do
    it "should parse ids from basename" do
      test = BagIt::NameParser.new(YAML.load(fixture("name_parsing_schema/p_c_numeric_basename.yml")))
      test.id("data/foo/ldpd_leh_12_34_56.tif").should == "ldpd.leh.12.34.56.R.image"
      test.id("data/foo/ldpd_leh_12_34_56V.tif").should == "ldpd.leh.12.34.56.V.image"
      test.parent("data/foo/ldpd_leh_12_34_56.tif").should == "ldpd_leh_12_34"
    end
  end

  describe "APT-style file IDs" do
    it "should parse ids from basename" do
      test = BagIt::NameParser.new(YAML.load(fixture("name_parsing_schema/apt_style.yml")))
      test.id("data/foo/ldpd_leh_12_34_56.tif").should == "apt://columbia.edu/ldpd.leh/data/foo/ldpd_leh_12_34_56.tif"
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

  describe "OBL" do
    it "should parse ids from basename" do
      test = BagIt::NameParser.new(YAML.load(fixture("name_parsing_schema/obl.yml")))
      test.id("data/foo/1.tif").should == "osamabinladen.01#image"
      test.id("data/foo/12.tif").should == "osamabinladen.12#image"
      test.parent("data/foo/1.tif").should == "osamabinladen.01"
    end
  end    
  describe "Urashima" do
    it "should parse ids from basename" do
      test = BagIt::NameParser.new(YAML.load(fixture("name_parsing_schema/urashima.yml")))
      test.id("data/foo/01boxcover.tif").should == "apt://columbia.edu/prd.urashima/data/foo/01boxcover.tif"
      test.id("data/foo/volume2_02.tif").should == "apt://columbia.edu/prd.urashima/data/foo/volume2_02.tif"
      test.parent("data/foo/1.tif").should == "prd.urashima.001"
    end
  end    
  describe "Shurin" do
    it "should parse ids from basename" do
      test = BagIt::NameParser.new(YAML.load(fixture("name_parsing_schema/shurin.yml")))
      test.id("data/foo/fish_18.tif").should == "apt://columbia.edu/prd.shurin/data/foo/fish_18.tif"
      test.parent("data/foo/18.tif").should == "prd.shurin.001"
    end
  end    
  describe "Lehman" do
    it "should parse ids from basename" do
      test = BagIt::NameParser.new(YAML.load(fixture("name_parsing_schema/lehman.yml")))
      test.id("data/S_LEH_K14/ldpd_leh_0483_0033_001.tif").should == "apt://columbia.edu/ldpd.leh/data/S_LEH_K14/ldpd_leh_0483_0033_001.tif"
      test.parent("data/S_LEH_K14/ldpd_leh_0483_0033_001.tif").should == "ldpd_leh_0483_0033"
    end
  end    
end