module Arxv
  class FileEntry
    attr_accessor :path, :derivatives, :mime, :format
    def initialize(opts,derivatives=nil)
      @path = opts[:path]
      @mime = opts[:mime]
      @format = opts[:format]
      @original = !!opts[:original]
      @derivatives = derivatives || []
    end
    def original?
      @original
    end
  end
end