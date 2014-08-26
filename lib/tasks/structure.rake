module Structure
  module Mets
    def self.serialize(k, v, out, indent=0)
      i = ''
      indent.times { i << ' '}
      if v.is_a? Hash
        if k.nil?
          out.print i + "<mets:structMap TYPE=\"physical\" LABEL=\"Device\" xmlns:mets=\"http://www.loc.gov/METS/\">\n"
        else
          out.print i + "<mets:div LABEL=\"#{k}\">\n"
        end
        v.each {|key,value| Mets.serialize(key, value,out,indent+2)}
        out.print i + (k.nil? ? "</mets:structMap>\n"  : "</mets:div>\n")
      else
        out.print i + "<mets:div LABEL=\"#{k.to_s}\" CONTENTIDS=\"#{v}\" />\n"
      end
    end
  end
end
namespace :structure do
  task :device => :environment do
    bag_path = ENV['BAG_PATH']
    alg = ENV['CHECKSUM_ALG'] || 'sha1'
    type = ENV['TYPE'] || 'mets'
    override = !!ENV['OVERRIDE'] and !(ENV['OVERRIDE'] =~ /^false$/i)
    upload_dir = ActiveFedora.config.credentials[:upload_dir]
    # parse bag-info for external-id and title
    bag_info = BagIt::Info.new(bag_path)
    raise "External-Identifier for bag is required" if bag_info.external_id.blank?
    cagg_id = "apt://columbia.edu/#{bag_info.external_id}/data"
    cagg = ContentAggregator.search_repo(identifier: cagg_id).first
    unless cagg.nil?
      manifest = File.join(bag_path, "manifest-#{alg}.txt")
      struct = {}
      open(manifest) do |blob|
        blob.each do |line|
          line.strip!
          path = line.split(' ')[1]
          path_parts = path.split('/')[1..-1]
          context = struct
          path_parts.each do |part|
            if part == path_parts.last
              context[part] ||= id_prefix + path
            else
              context[part] ||= {}
              context = context[part]
            end
          end
        end
      end
      open(File.join(bag,'structMetadata.xml'), 'w') do |out|
        Structure::Mets.serialize(nil, struct, out)
      end
      # and then add it to the CAGG
      temp_content = temp_file.read
      structMetadata = cagg.datastreams['structMetadata']
      content = structMetadata.content
      if content != temp_content
        structMetadata.content = temp_content
        structMetadata.mimeType = 'text/xml'
        structMetadata.label = 'structMetadata.xml'
        cagg.save
      end

    else
      puts "No ContentAggregator found for #{cagg_id}"
    end
  end
end