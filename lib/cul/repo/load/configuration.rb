module Cul::Repo::Load
  class Configuration
    DEFAULT_CHECKSUM = 'sha1'.freeze
    DEFAULT_OFFSET = 0

    attr_accessor :bag_path, :checksum_alg, :offset, :override,
                  :pattern, :relationships, :skip_parent_works

    def initialize(*args)
      opts = args.extract_options!
      self.bag_path = opts[:bag_path]
      self.checksum_alg = opts[:checksum_alg]
      self.skip_parent_works = opts[:skip_parent_works]
      self.pattern = opts[:pattern]
      self.offset = opts[:offset]
      self.override = opts[:override]
      self.relationships = opts.fetch(:relationships,{}).symbolize_keys
    end
    def checksum_alg=(val)
      @checksum_alg = val ? val : DEFAULT_CHECKSUM
    end
    def create_parent_works?
      !skip_parent_works
    end
    def skip_parent_works=(val)
      @skip_parent_works = !!val and (val.to_s =~ /^true$/i)
    end
    def pattern=(val)
      if val.is_a? String
        @pattern = Regexp.compile(val)
      else
        @pattern = val
      end
    end
    def offset=(val)
      @offset = val ? val.to_i : DEFAULT_OFFSET
    end
    def override=(val)
      @override = !!val and !(val.to_s =~ /^false$/i)
    end
    def upload_dir
      ActiveFedora.config.credentials[:upload_dir]
    end
    def derivative_options(cached=true)
      @derivative_options = nil unless cached
      @derivative_options ||= begin
        o = {:override => self.override}
        o[:upload_dir] = self.upload_dir.clone.untaint if self.upload_dir
        o       
      end
    end
    def self.from_env
      if ENV['LOAD_CONFIG']
        from_yml(ENV['LOAD_CONFIG'])
      else
        Configuration.new(env_to_opts)
      end
    end
    def self.from_yml(path)
      yml = open(path) {|b| YAML.load(b.read)}
      yml.symbolize_keys!
      opts = env_to_opts.merge(yml)
      opts.symbolize_keys!
      Configuration.new(opts)
    end
    private
    def self.env_to_opts
      opts = {}
      opts[:bag_path] = ENV['BAG_PATH']
      opts[:checksum_alg] = ENV.fetch('CHECKSUM_ALG', DEFAULT_CHECKSUM)
      opts[:pattern] = ENV['PATTERN']
      opts[:offset] = ENV.fetch('SKIP',DEFAULT_OFFSET).to_i
      opts[:override] = ENV['OVERRIDE']
      opts[:skip_parent_works] = ENV['ORPHAN']
      opts.symbolize_keys!
      opts
    end
  end
end