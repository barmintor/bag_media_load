require 'bag_it'
module Arxv
  class Entry < BagIt::Manifest::Entry
    attr_accessor :path, :derivatives, :mime
    def initialize(opts,derivatives=nil)
      super(opts)
      @original = !!opts[:original]
      @derivatives = derivatives || []
    end
    def original?
      @original
    end
  end
end