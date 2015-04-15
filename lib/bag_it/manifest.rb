require 'active_support'
require 'mime/types'
module BagIt
  class Manifest
    include BagIt::DcHelpers
    include BagIt::ImageHelpers

    IMAGE_TYPES = ["image/bmp", "image/gif", "imag/jpeg", "image/png", "image/tiff", "image/x-windows-bmp"]

    DOC_TYPES = MIME::Types.type_for('pdf') + MIME::Types.type_for('doc') +
                 MIME::Types.type_for('rtf') + MIME::Types.type_for('docx')

    PRESENTATION_TYPES = MIME::Types.type_for('ppt') + MIME::Types.type_for('pptx')

    SPREADSHEET_TYPES = MIME::Types.type_for('xls') + MIME::Types.type_for('xlsx')

    XML_TYPES = MIME::Types.type_for('xml')

    TEXT_TYPES = MIME::Types.type_for('txt')

    AUDIO_TYPES = MIME::Types.type_for('mp3') + MIME::Types.type_for('wav') +
                  MIME::Types.type_for('aiff') + MIME::Types.type_for('au') +
                  MIME::Types.type_for('aac') + MIME::Types.type_for('oga')

    VIDEO_TYPES = MIME::Types.type_for('mp4') + MIME::Types.type_for('mov') +
                  MIME::Types.type_for('avi') + MIME::Types.type_for('ogv') +
                  MIME::Types.type_for('webm') + MIME::Types.type_for('qt')

    OCTETSTREAM = "application/octet-stream"

    autoload :Entry, 'bag_it/manifest/entry'

    def initialize(manifest, name_parser)
      if manifest.is_a? File
        @manifest = manifest.path # we need to be able to re-open this file
      else
        @manifest = manifest
      end
      @bagdir = File.dirname(@manifest)
      @name_parser = name_parser
    end

    def name_parser
      @name_parser
    end

    def path_matcher(only_data=nil)
      if only_data.is_a? String
        only_data = only_data.dup
        only_data.sub!(/^\/data/,'data')
        only_data = Regexp.compile(Regexp.escape(only_data))
      end
      only_data
    end

    def each_entry(only_data=nil)
      file= open(@manifest)
      only_data = path_matcher(only_data)
      file.each do |line|
        next if line =~ /\.md5$/ # don't load checksum files
        rel_path = line.split(' ')[1..-1].join(' ')
        next if only_data and !(rel_path =~ only_data)
        source = File.join(@bagdir, rel_path)
        yield Entry.new(path:source, mime: (Manifest.mime_for_name(source) || OCTETSTREAM))
      end
    end

    def entries(only_data=nil)
      entries = []
      each_entry(only_data) {|e| entries << e }
      entries
    end    

    def each_resource(create=false, only_data=nil)
      each_entry(only_data) {|source| yield find_or_create_resource(source, nil, create) }
    end

    def find_or_create_resource(dc_source_or_entry, name_parser=nil, create=false)
      name_parser ||= name_parser()
      unless dc_source_or_entry.is_a? Entry
        dc_source_or_entry = entry_for(dc_source_or_entry)
      end
      dc_source = dc_source_or_entry.path
      sources = Manifest.sources(dc_source)
      resource = Manifest.find_for_sources(sources)
      if resource.blank?
        return nil unless create
        resource = GenericResource.new(:pid => BagIt.next_pid)
        resource.save
      end
      unless resource.datastreams['content'] and !resource.datastreams['content'].new?
        mimetype = Manifest.mime_for_name(sources[0])
        mimetype ||= OCTETSTREAM
        ds_size = File.stat(dc_source).size.to_s
        ds = resource.datastreams['content']
        dsLocation = sources[1].clone
        dsLocation.gsub!(' ','%20')
        dsLocation.gsub!('#','%23')
        if ds and !ds.new?
          ds.dsLocation = dsLocation
          ds.dsLabel = sources[0].split('/').last
          ds.save
        else
          ds = resource.create_datastream(ActiveFedora::Datastream, 'content', :dsLocation=>dsLocation, :controlGroup => 'E', :mimeType=>mimetype, :dsLabel=>sources[0].split('/').last)
          resource.add_datastream(ds)
          ds.save
        end
        begin
          if dc_source_or_entry.image?
              setImageProperties(resource)
          elsif dc_source_or_entry.dc_type.eql? 'Software'
            Rails.logger.warn "WARN: Unsupported MIME Type #{mimetype} for #{sources[0]}"
          end
          resource.set_dc_format dc_source_or_entry.mime
          resource.set_dc_type dc_source_or_entry.dc_type
          resource.set_dc_title dc_source_or_entry.title if resource.datastreams['DC'].term_values(:dc_title).blank?

        rescue Exception => e
          Rails.logger.warn "WARN failed to analyze image at #{sources[0]} : #{e.message}"
          Rails.logger.warn "WARN ingesting as unidentified bytestream"
          resource.set_dc_format dc_source_or_entry.mime
          resource.set_dc_type dc_source_or_entry.dc_type
          resource.set_dc_title dc_source_or_entry.title if resource.datastreams['DC'].term_values(:dc_title).blank?
        end
        bag_entry = sources[0].slice((sources[0].index('/data/') + 1)..-1)
        resource.add_dc_identifier name_parser.id(bag_entry) if name_parser.id(bag_entry)
        resource.add_dc_identifier name_parser.default.id(bag_entry)
        resource.set_dc_source sources[0]
        resource.set_dc_extent ds_size
      end
      resource.migrate!
      resource
    end

    def entry_for(dc_source)
      Manifest.entry_for(dc_source)
    end

    def self.find_resource(dc_source)
      find_for_sources(sources(dc_source))
    end
    def self.find_for_sources(sources)
      resource = nil
      sources.each do |source|
        source = source.gsub(/~/,'?') || source  # tilde is an operator in search
        source = source.gsub(/'/,'?') || source # illegal character
        source = source.gsub(/&/,'?') || source # illegal character
        source = source.gsub(' ','?') || source # illegal character
        resource ||= GenericResource.search_repo(source: source).first
        if resource
          break
        end
      end
      return resource
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
      Entry.mime_for_name(filename)
    end
    def self.entry_for(dc_source)
      opts = {path: dc_source, mime: mime_for_name(dc_source), local_id: 'content'}
      Entry.new(opts)
    end
  end
end