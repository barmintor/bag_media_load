require 'pathname'
module BagIt
  class Info
    ARCHIVEMATICA_PROFILES = [
      "https://cdn.cul.columbia.edu/bagit-profiles/archivematica.json"
    ]
    def self.path_for(bag_path)
      if bag_path.respond_to? :path
        bag_path = bag_path.path
      end
      if File.basename(bag_path) == 'bag-info.txt'
        bag_path = File.dirname(bag_path)
      end
      bag_path
    end
    attr_accessor :count, :bag_path
    def initialize(src_file)
      @bag_path = Info.path_for(src_file)
      src_file = open(File.join(@bag_path,'bag-info.txt'))
      @options = {}
      src_file.each do |line|
        parts = line.strip.split(':',2)
        @options[parts[0]] = parts[1].strip
        if parts[0] == "Payload-Oxum"
          @count = parts[1].strip.split('.')[1].to_i
        end
      end
    end
    def [](key)
      @options[key]
    end
    def external_id
      self["External-Identifier"]
    end
    def external_desc
      self["External-Description"]
    end
    def group_id
      self["Bag-Group-Identifier"]
    end
    def profile_id
      self["BagIt-Profile-Identifier"]
    end
    def id_schema
      self["Local-Identifier-Schema"]
    end
    def archivematica?
      ARCHIVEMATICA_PROFILES.include? profile_id
    end
    def id_for(input)
      @id_schema ||= begin
        ids = BagIt::NameParser::Default.new(external_id())
        if (schema_path = id_schema())
          schema_path = Pathname.new(schema_path)
          if (schema_path.relative?)
            schema_path = Pathname.new(bag_path()) + schema_path
          end
          schema_path = schema_path.cleanpath
          def_schema = ids
          ids = BagIt::NameParser.new(YAML.load(File.open(schema_path)))
          ids.default = def_schema
        end
        ids
      end
      @id_schema.id(input)
    end
  end
end
