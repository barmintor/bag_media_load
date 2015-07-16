require 'tempfile'
require 'cul_repo_cache'
namespace :structure do
  task :fix => :environment do
    broken = [
      "file:///fstore/archive/ldpd/preservation/customer_orders/data/pre2008/060081008.tif",
      "file:///fstore/archive/ldpd/preservation/customer_orders/data/pre2008/040183001.tif",
      "file:///fstore/archive/ldpd/preservation/customer_orders/data/pre2008/040190001.tif",
      "file:///fstore/archive/ldpd/preservation/customer_orders/data/pre2008/050005001.tif",
      "file:///fstore/archive/ldpd/preservation/customer_orders/data/pre2008/050005003.tif",
      "file:///fstore/archive/ldpd/preservation/customer_orders/data/pre2008/060128016.tif"
    ]
    ctr = 0
    total = broken.length
    broken.each do |old_source|
      basename = old_source.split('/')[-1]
      new_path = nil
      if (match = /(\d{6,6})/.match(basename))
        new_path = "data/pre2008/order##{match[1]}/#{basename}"
      else
        new_path = "data/pre2008/#{basename}"
      end
      new_source = "file:///fstore/archive/ldpd/preservation/customer_orders/#{new_path}"
      ctr += 1
      puts "#{old_source} -> #{new_source} #{ctr} of #{total}"
      Rails.logger.info("#{old_source} -> #{new_source} #{ctr} of #{total}")
      new_id = "apt://columbia.edu/prd.custord/#{new_path}"

      begin
        resource = Resource.search_repo(source: old_source).first
        if resource
          Rails.logger.info("\tFound #{resource.pid} for #{old_source}")
          resource.datastreams['CONTENT'].dsLocation = new_source
          resource.save
          Rails.logger.info("\t<#{resource.pid}>/CONTENT.dsLocation -> #{new_source}")
          dc = resource.datastreams['DC']
          dc.update_values({[:dc_identifier] => [new_id]})
          dc.update_values({[:dc_source] => [new_source]})
          resource.save
          Rails.logger.info("\t<#{resource.pid}>/DC.identifier -> #{new_id}")
          Rails.logger.info("\t<#{resource.pid}>/DC.source -> #{new_source}")
        else
          Rails.logger.warn("NOT FOUND #{old_source}")
        end
      rescue Exception => e
        Rails.logger.error(e.message)
      end     
    end
  end

  task :custord => :environment do
    # old source file:///fstore/archive/ldpd/preservation/customer_orders_pre2008/data/050063004.tif
    # old dsLoca file:///fstore/archive/ldpd/preservation/customer_orders_pre2008/data/050063004.tif
    # new source file:///fstore/archive/ldpd/preservation/customer_orders/data/pre2008/order#050063/050063004.tif
    manifest = "custord_manifest.txt"
    old_paths = []
    open(manifest) do |blob|
      blob.each do |line|
        path = line.split(' ')[-1]
        path.strip!
        old_paths << path unless path.blank?
      end
    end
    total = old_paths.length
    ctr = -1
    old_paths.each do |old_path|
      basename = File.basename(old_path)
      new_path = nil
      if (match = /(\d{6,6})/.match(basename))
        new_path = "data/pre2008/order##{match[1]}/#{basename}"
      else
        new_path = "data/pre2008/#{basename}"
      end
      ctr += 1
      puts "#{old_path} -> #{new_path} #{ctr} of #{total}"
      Rails.logger.info("#{old_path} -> #{new_path} #{ctr} of #{total}")
      new_id = "apt://columbia.edu/prd.custord/#{new_path}"
      new_source = "file:///fstore/archive/ldpd/preservation/customer_orders/#{new_path}"
      old_source = "file:///fstore/archive/ldpd/preservation/customer_orders_pre2008/data/#{basename}"
      begin
        resource = Resource.search_repo(source: old_source).first
        if resource
          Rails.logger.info("\tFound #{resource.pid} for #{old_source}")
          resource.datastreams['CONTENT'].dsLocation = new_source
          resource.save
          Rails.logger.info("\t<#{resource.pid}>/CONTENT.dsLocation -> #{new_source}")
          dc = resource.datastreams['DC']
          dc.update_values({[:dc_identifier] => [new_id]})
          dc.update_values({[:dc_source] => [new_source]})
          resource.save
          Rails.logger.info("\t<#{resource.pid}>/DC.identifier -> #{new_id}")
          Rails.logger.info("\t<#{resource.pid}>/DC.source -> #{new_source}")
        else
          Rails.logger.warn("NOT FOUND #{old_source}")
        end
      rescue Exception => e
        Rails.logger.error(e.message)
      end     
    end

  end
  task :device => :environment do
    bag_path = ENV['BAG_PATH']
    alg = ENV['CHECKSUM_ALG'] || 'sha1'
    type = ENV['TYPE'] || 'mets'
    override = !!ENV['OVERRIDE'] and !(ENV['OVERRIDE'] =~ /^false$/i)
    upload_dir = ActiveFedora.config.credentials[:upload_dir]
    # parse bag-info for external-id and title
    bag_info = BagIt::Info.new(bag_path)
    raise "External-Identifier for bag is required" if bag_info.external_id.blank?
    if bag_info.external_id =~ /^apt:\/\//
      id_prefix = bag_info.external_id
    else
      id_prefix = "apt://columbia.edu/#{bag_info.external_id}"
    end
    cagg_id = "#{id_prefix}/data"
    cagg = ContentAggregator.search_repo(identifier: cagg_id).first
    unless cagg.nil?
      temp_file = Tempfile.new('structMetadata')
      open(temp_file.path, 'w') do |out|
        bag_info.structure(alg,id_prefix,out)
      end
      # and then add it to the CAGG
      temp_content = temp_file.read
      temp_file.unlink
      structMetadata = cagg.datastreams['structMetadata']
      content = structMetadata.content
      if content != temp_content
        structMetadata.content = temp_content
        structMetadata.type = RDF::NFO[:"#Filesystem"].to_s
        structMetadata.mimeType = 'text/xml'
        structMetadata.dsLabel = 'structMetadata.xml'
        cagg.save
        cagg.datastreams['DC'].update_values([:dc_type]=>'FileSystem')
        cagg.save
      end

    else
      puts "No ContentAggregator found for #{cagg_id}"
    end
  end
end