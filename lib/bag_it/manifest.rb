require 'active_support'
require 'mime/types'
module BagIt
  class Manifest
    include BagIt::DcHelpers
    extend BagIt::ImageHelpers
    IMAGE_TYPES = ["image/bmp", "image/gif", "imag/jpeg", "image/png", "image/tiff", "image/x-windows-bmp"]
    OCTETSTREAM = "application/octet-stream"
    def initialize(manifest)
      if manifest.is_a? File
        @manifest = manifest.path # we need to be able to re-open this file
      else
        @manifest = manifest
      end
      @bagdir = File.dirname(@manifest)
    end

    def each_entry
      file= open(@manifest)
      file.each do |line|
        next if line =~ /\.md5$/ # don't load checksum files
        rel_path = line.split(' ')[1]
        source = File.join(@bagdir, rel_path)
        yield source
      end
    end
    
    def each_resource
      file= open(@manifest)
      file.each do |line|
        next if line =~ /\.md5$/ # don't load checksum files
        rel_path = line.split(' ')[1]
        source = File.join(@bagdir, rel_path)
        yield Manifest.find_or_create_resource(source)
      end
    end
    
    def self.find_resource(dc_source)
      resource = nil
      sources(dc_source).each do |source|
        source = source.sub(/~/,'?') # tilde is an operator in search
        resource ||= GenericResource.find_by_source(source)
      end
      return resource
    end
    
    def self.find_or_create_resource(dc_source, create=false)
      resource = find_resource(dc_source)
      if resource.blank?
        sources = Manifest.sources(dc_source)
        mimetype = mime_for_name(sources[0])
        mimetype ||= OCTETSTREAM
        resource = GenericResource.new(:pid => BagIt.next_pid)
        ds_size = File.stat(dc_source).size.to_s
        ds = resource.datastreams['content']
        if ds
          ds.dsLocation = sources[1]
          ds.dsLabel = sources[0]
        else
          ds = resource.create_datastream(ActiveFedora::Datastream, 'content', :dsLocation=>sources[1], :controlGroup => 'E', :mimeType=>mimetype, :dsLabel=>sources[0])
          resource.add_datastream(ds)
        end
        if IMAGE_TYPES.include? mimetype
          begin
            setImageProperties(resource)
            resource.set_dc_format mimetype
            resource.set_dc_type 'Image'
            resource.set_title 'Preservation Image' if resource.dc.title.blank?
          rescue Exception => e
            puts "WARN failed to analyze image at #{sources[0]} : #{e.message}"
            puts "WARN ingesting as unidentified bytestream"
            resource.set_dc_format OCTETSTREAM
            resource.set_title 'Preservation File Artifact' if resource.dc.title.blank?
          end
        else
          puts "WARN: Unsupported MIME Type #{mimetype} for #{sources[0]}"
        end
        resource.set_dc_identifier sources[0]
        resource.set_dc_source sources[0]
        resource.set_dc_extent ds_size
        resource.save if create
      else
        resource.migrate!
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
      mt = MIME::Types.type_for(ext)
      if mt.is_a? Array
        mt = mt.first
      end
      unless mt.nil?
        return mt.content_type
      else
        return nil
      end
    end
  end
end
