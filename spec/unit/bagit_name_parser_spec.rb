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
      test.id("data/foo/ldpd_leh_12_34_56.tif").should == "apt://columbia.edu/ldpd_leh/data/foo/ldpd_leh_12_34_56.tif"
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
      test.parent("data/foo/18.tif").should be_nil
      test.parent("data/foo/fish_18.tif").should == "prd.shurin.001"
    end
  end    
  describe "Lehman" do
    it "should parse ids from basename" do
      test = BagIt::NameParser.new(YAML.load(fixture("name_parsing_schema/lehman.yml")))
      test.id("data/S_LEH_K14/ldpd_leh_0483_0033_001.tif").should == "apt://columbia.edu/ldpd_leh/data/S_LEH_K14/ldpd_leh_0483_0033_001.tif"
      test.parent("data/S_LEH_K14/ldpd_leh_0483_0033_001.tif").should == "ldpd_leh_0483_0033"
    end
  end
  describe "Urban" do
    it "should parse ids from basename" do
      test = BagIt::NameParser.new(YAML.load(fixture("name_parsing_schema/urban.yml")))
      test.id("data/color_urban/3508020101.tif").should == "apt://columbia.edu/rbml.urban/data/color_urban/3508020101.tif"
      test.parent("data/color_urban/3508020101.tif").should == "rbml.urban.3508020101"
    end
  end
  describe "Aviador" do
    it "should parse ids from basename" do
      test = BagIt::NameParser.new(YAML.load(fixture("name_parsing_schema/aviador.yml")))
      test.id("data/NYDA.1960.001.03238R.tif").should == "NYDA.1960.001.03238R"
      test.parent("NYDA.1960.001.03238R.tif").should be_nil
    end
  end
  describe "APIS" do
    it "should parse ids from basename" do
      test = BagIt::NameParser.new(YAML.load(fixture("name_parsing_schema/apis.yml")))
      test.id("data/6/columbia.apis.p206.f.0.600.tif").should == "columbia.apis.p206.f"
      test.parent("data/6/columbia.apis.p206.f.0.600.tif").should == 'columbia.apis.p206'
      test.side("data/6/columbia.apis.p206.f.0.600.tif").should == 'R'
      test.side("data/6/columbia.apis.p206.b.0.600.tif").should == 'V'
    end
  end
  describe BagIt::NameParser::Default do
    it "should parse ids when the external id is already apt-style" do
      test = BagIt::NameParser::Default.new('apt://foo')
      test.id("data/bar.txt").should == "apt://foo/data/bar.txt"
    end
    it "should parse ids when the external id is not an apt-style uri" do
      test = BagIt::NameParser::Default.new('foo')
      test.id("data/bar.txt").should == "apt://columbia.edu/foo/data/bar.txt"
      test.id("/data/bar.txt").should == "apt://columbia.edu/foo/data/bar.txt"
      test = BagIt::NameParser::Default.new('/foo/')
      test.id("data/bar.txt").should == "apt://columbia.edu/foo/data/bar.txt"
      test.id("/data/bar.txt").should == "apt://columbia.edu/foo/data/bar.txt"
    end
  end
end