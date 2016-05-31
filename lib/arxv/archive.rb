require 'nokogiri'
require 'bag_it'
module Arxv
  class Archive < BagIt::Manifest
    METS_NS = {
      mets: "http://www.loc.gov/METS/",
      premis: "info:lc/xmlns/premis-v2",
      fits: "http://hul.harvard.edu/ois/xml/ns/fits/fits_output",
      xlink: "http://www.w3.org/1999/xlink",
      xsi: "http://www.w3.org/2001/XMLSchema-instance"
    }
    def initialize(bag_info)
      bag_info = BagIt::Info.new(bag_info) if bag_info.is_a? String
      raise "The bag at #{bag_info.bag_path} is not an Archivematica bag" unless bag_info.archivematica?
      @bag_info = bag_info
      mets_path = Dir.entries(File.join(bag_info.bag_path,'data')).select {|x| x =~ /^METS\..+\.xml$/}
      mets_path = File.join(bag_info.bag_path,'data',mets_path.first)
      @mets = Nokogiri::XML(open(mets_path)) { |config| config.strict.noblanks }
    end
    # return the Arxv::FileEntry objects associated with the original files of this archive
    def each_entry(only_data=nil)
      only_data = path_matcher(only_data)
      original_fg = file_group(@mets,"original").first
      file_entries = original_fg.xpath("mets:file", METS_NS).collect do |file|
        gid = file["GROUPID"]
        pres_file_group = file_group(@mets,"preservation").first
        if pres_file_group
          derivatives = pres_file_group.xpath("mets:file[@GROUPID='#{gid}']", METS_NS)
        else
          derivatives = []
        end
        entry = file_entry(file)
        entry.derivatives = derivatives.collect {|node| file_entry(node,false)}
        if !only_data || entry.path =~ only_data
          yield entry
        end
      end
    end
    def file_group(doc,use)
      doc.xpath("/mets:mets/mets:fileSec/mets:fileGrp[@USE='#{use}']", METS_NS)
    end
    def file_path(file_node)
      File.absolute_path(File.join(@bag_info.bag_path,'data',file_node.xpath('mets:FLocat',METS_NS).first["xlink:href"]))
    end
    def file_entry(file_node,original=true)
      local_id = file_node['ID']
      opts = {path: file_path(file_node), local_id:local_id,original:original}
      document = file_node.document
      adm_id = file_node['ADMID']
      if adm_id
        adm = Arxv::AmdSec.new(document.xpath("//mets:amdSec[@ID='#{adm_id}']", METS_NS).first)
        opts[:mime] = adm.mime_type
        opts[:puid] = adm.puid
        if original
          opts[:original_path] = adm.original_path
        end
      end
      Arxv::Entry.new(opts)
    end
    def entry_for(dc_source)
      opts = {path: dc_source, mime: mime_for_name(dc_source), local_id: 'content'}
      Arxv::Entry.new(opts)
    end
    # return the GenericResource objects associated with the archive's entries
    def resources
      []
    end
    def name_parser
      @bag_info.id_factory
    end
  end
end