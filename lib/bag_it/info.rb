module BagIt
  class Info
    attr_accessor :external_id, :external_desc, :group_id, :id_schema
    def initialize(src_file)
      @id_schema = BagIt::NameParser::Default.new
      src_file = open(src_file) if src_file.is_a? String
      src_file.each do |line|
        parts = line.strip.split(':',2)
        if parts[0] == "External-Identifier"
          @external_id = parts[1].strip
        end
        if parts[0] == "External-Description"
          @external_desc = parts[1].strip
        end
        if parts[0] == "Bag-Group-Identifier"
          @group_id = parts[1].strip
        end
        if parts[0] == "Local-Identifier-Schema"
          @id_schema = BagIt::NameParser.new(YAML.load(open(parts[1].strip)))
        end
      end
    end
  end
end
