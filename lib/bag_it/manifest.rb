require 'active_support'
require 'mime/types'
module BagIt
  class Manifest
    include BagIt::DcHelpers
    extend BagIt::ImageHelpers
    IMAGE_TYPES = ["image/bmp", "image/gif", "imag/jpeg", "image/png", "image/tiff", "image/x-windows-bmp"]
    OCTETSTREAM = "application/octet-stream"
    def initialize(manifest, name_parser)
      if manifest.is_a? File
        @manifest = manifest.path # we need to be able to re-open this file
      else
        @manifest = manifest
      end
      @bagdir = File.dirname(@manifest)
      @name_parser = name_parser
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
    
    def each_resource(create=false, only_data=nil)
      file= open(@manifest)
      if only_data.is_a? String
        only_data = only_data.dup
        only_data.sub!(/^\/data/,'data')
        only_data = Regexp.compile(Regexp.escape(only_data))
      end
      file.each do |line|
        next if line =~ /\.md5$/ # don't load checksum files
        rel_path = line.split(' ')[1]
        next if only_data and !(rel_path =~ only_data)
        source = File.join(@bagdir, rel_path)
        yield rel_path, Manifest.find_or_create_resource(source, @name_parser, create)
      end
    end
    
    def self.find_resource(dc_source)
      resource = nil
      sources(dc_source).each do |source|
        source = source.sub(/~/,'?') # tilde is an operator in search
        source = source.sub(/'/,'?') # illegal character
        source = source.sub(/&/,'?') # illegal character
        resource ||= GenericResource.search_repo(source: source).first
        if resource
          break
        end
      end
      return resource
    end
    
    def self.find_or_create_resource(dc_source, name_parser, create=false)
      sources = Manifest.sources(dc_source)
      resource = find_resource(dc_source)
      if resource.blank?
        return nil unless create
        resource = GenericResource.new(:pid => BagIt.next_pid)
        resource.save
      end
      unless resource.datastreams['content'] and !resource.datastreams['content'].new?
        mimetype = mime_for_name(sources[0])
        mimetype ||= OCTETSTREAM
        ds_size = File.stat(dc_source).size.to_s
        ds = resource.datastreams['content']
        if ds and !ds.new?
          ds.dsLocation = sources[1]
          ds.dsLabel = sources[0]
          ds.save
        else
          ds = resource.create_datastream(ActiveFedora::Datastream, 'content', :dsLocation=>sources[1], :controlGroup => 'E', :mimeType=>mimetype, :dsLabel=>sources[0])
          resource.add_datastream(ds)
          ds.save
        end
        if IMAGE_TYPES.include? mimetype
          begin
            setImageProperties(resource)
            resource.set_dc_format mimetype
            resource.set_dc_type 'Image'
            resource.set_dc_title 'Preservation Image' if resource.datastreams['DC'].term_values(:dc_title).blank?
          rescue Exception => e
            Rails.logger.warn "WARN failed to analyze image at #{sources[0]} : #{e.message}"
            Rails.logger.warn "WARN ingesting as unidentified bytestream"
            resource.set_dc_format OCTETSTREAM
            resource.set_dc_title 'Preservation File Artifact' if resource.datastreams['DC'].term_values(:dc_title).blank?
          end
        else
          Rails.logger.warn "WARN: Unsupported MIME Type #{mimetype} for #{sources[0]}"
        end
        bag_entry = sources[0].slice((sources[0].index('/data/') + 1)..-1)
        resource.add_dc_identifier name_parser.id(bag_entry) if name_parser.id(bag_entry)
        resource.add_dc_identifier name_parser.default.id(bag_entry)
        resource.set_dc_source sources[0]
        resource.set_dc_extent ds_size
        resource.migrate!
      else
        resource.migrate!
      end
      resource
    end
    
    def self.sources(dc_source)
      uri = nil
      alt_uri = nil
      dc_source.sub!(/^file\:[\/]+/,'/')
      if dc_source
        sources = [
          dc_source,
          'file:' + dc_source,
          'file:/' + dc_source,
          'file://' + dc_source
        ]
        return sources
      end
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
