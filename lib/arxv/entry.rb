require 'bag_it'
module Arxv
  class Entry < BagIt::Manifest::Entry
    attr_accessor :path, :derivatives, :mime
    def initialize(opts,derivatives=nil)
      super(opts)
      @original = !!opts[:original]
      @derivatives = derivatives || []
      @original_path = opts[:original_path].gsub('%transferDirectory%objects/','') if opts[:original_path]
    end
    def original?
      @original
    end
    def original_path
      @original_path || path
    end
    def title
      @title || original_path
    end
  end
end