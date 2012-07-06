require 'active_support'
require 'mime/types'
module Bag
  class Manifest
    extend Bag::ImageHelpers
    IMAGE_TYPES = ["image/bmp", "image/gif", "imag/jpeg", "image/png", "image/tiff", "image/x-windows-bmp"]
    def initialize(manifest)
      if manifest.is_a? File
        @manifest = manifest.path # we need to be able to re-open this file
      else
        @manifest = manifest
      end
      @bagdir = File.dirname(@manifest)
    end
    
    def each_resource
      file= open(@manifest)
      file.each do |line|
        rel_path = line.split(' ')[1]
        source = @bagdir + '/' + rel_path
        yield Manifest.find_or_create(source)
      end
    end
    
    def self.find_resource(dc_source)
      resource = nil
      sources(dc_sources).each do |source|
        resource ||= Resource.find_by_source(source)
      end
      return resource
    end
    
    def self.find_or_create_resource(dc_source, create=false)
      resource = find_resource(dc_source)
      if resource.blank?
        sources = Manifest.sources(dc_source)
        mimetype = mime_for_name(sources[0])
        resource = Resource.new(:namespace=>'ldpd')
        ds_size = File.stat(dc_source).size.to_s
        ds = resource.create_datastream(:dsid => 'CONTENT', :dsLocation=>sources[1], :controlGroup => 'E', :mimeType=>mimetype, :label=>sources[0])
        resource.add_datastream(ds)
        if IMAGE_TYPES.include? mimetype
          setImageProperties(resource)
        end
        resource.dc.identifier = sources[0]
        resource.dc.source = sources[0]
        resource.dc.format = mimetype
        resource.dc.type = 'Image'
        resource.dc.title = 'Preservation Image'
        resource.dc.extent = ds_size
        resource.save if create
      end
      resource
    end
    
    def self.sources(dc_source)
      uri = nil
      alt_uri = nil
      if dc_source =~ /(^file\:)(\/\/)?(.*)/
        unless $2.blank?
          uri = $1 + $3
          alt_uri = dc_source
          dc_source = $3
        else
          uri = dc_source
          alt_uri = 'file://' + $3
          dc_source = $3
        end
      else
        uri = 'file:' + dc_source
        alt_uri = 'file://' + dc_source
      end
      return [dc_source, uri, alt_uri]
    end
    
    def self.mime_for_name(filename)
      ext = File.extname(filename).downcase
      mt = MIME::Types.for(ext)
      if mt.is_a? Array
        mt = mt.first
      end
      mt.content_type
    end
  end
end