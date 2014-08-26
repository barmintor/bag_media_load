require 'pathname'
module BagIt
  class Info
    def self.path_for(bag_path)
      if bag_path.respond_to? :path
        bag_path = bag_path.path
      end
      if File.basename(bag_path) == 'bag-info.txt'
        bag_path = File.dirname(bag_path)
      end
      bag_path
    end
    attr_accessor :external_id, :external_desc, :group_id, :id_schema, :count, :bag_path
    def initialize(src_file)
      @bag_path = Info.path_for(src_file)
      src_file = open(File.join(@bag_path,'bag-info.txt'))
      src_file.each do |line|
        parts = line.strip.split(':',2)
        if parts[0] == "External-Identifier"
          @external_id = parts[1].strip
        end
        @id_schema = BagIt::NameParser::Default.new(@external_id)
        if parts[0] == "External-Description"
          @external_desc = parts[1].strip
        end
        if parts[0] == "Bag-Group-Identifier"
          @group_id = parts[1].strip
        end
        if parts[0] == "Payload-Oxum"
          @count = parts[1].strip.split('.')[1].to_i
        end
        if parts[0] == "Local-Identifier-Schema"
          path = parts[1].strip
          path = Pathname.new(path)
          if (path.relative?)
            path = Pathname.new(src_file.path).dirname + path
          end
          path = path.cleanpath
          @id_schema = BagIt::NameParser.new(YAML.load(File.open(path)))
        end
      end
    end
  end
end
