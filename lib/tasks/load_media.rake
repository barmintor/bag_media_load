require "rake"
require "active-fedora"
require "cul_scv_hydra"
require "nokogiri"
require "bag_it"
LDPD_COLLECTIONS_ID = 'http://libraries.columbia.edu/projects/aggregation'
def get_mods_nodes()
  file = File.new('fixtures/lindquist-mods.xml')
  mods_collection = Nokogiri::XML.parse(file)
  ns = {'mods' => 'http://www.loc.gov/mods/v3'}
  return mods_collection.xpath('/mods:modsCollection/mods:mods', ns)
end

def get_ldpd_content_pid
  BagAggregator.find_by_identifier(LDPD_COLLECTIONS_ID)
end

def get_bag_pid(bag_id)
  BagAggregator.find_by_identifier(bag_id)
end

def rubydora
  ActiveFedora::Base.fedora_connection[0] ||= ActiveFedora::RubydoraConnection.new(ActiveFedora.config.credentials)
  ActiveFedora::Base.fedora_connection[0].connection
end

def next_pid
  BagIt.next_pid
end

namespace :bag do
  task :pid do
    Rails.logger.info BagIt.next_pid
  end
  task :load_fixtures do
    ActiveFedora::Base.fedora_connection[0] ||= ActiveFedora::RubydoraConnection.new(ActiveFedora.config.credentials)
    rubydora = ActiveFedora::Base.fedora_connection[0].connection
    Dir[Rails.root.join("fixtures/cmodels/*.xml")].each {|f| Rails.logger.info rubydora.ingest :file=>open(f)}
  end
  namespace :media do
    desc "debug derivative creation"
    task :debug => :environment do
      rpath = '/fstore/archive/ldpd/preservation/lindquist/data/Lindquist_box_OS/burke_lindq_OS_1907v.tif'
      resource = GenericResource.find_by_source(rpath)
      Rails.logger.info "Found image at #{resource.pid}"
      resource.migrate!
      resource.derivatives!
      resource.datastreams.each_key do |key|
        ds = resource.datastreams[key]
        Rails.logger.info "#{resource.pid}##{ds.dsid}.dsSize : #{ds.dsSize}"
      end
    end
    desc "load CSS media"
    task :load_css => [:environment] do

      group_id = "rbml_css"

      css = BagAggregator.find_by_identifier(group_id)
      if css.blank?
        all_ldpd_content = BagAggregator.find_by_identifier(LDPD_COLLECTIONS_ID)
        css_pid = next_pid
        css = BagAggregator.new(:pid=>css_pid)
        css.datastreams["DC"].identifier = group_id
        css.datastreams["DC"].title = "Community Service Society Records"
        css.datastreams["DC"].dc_type = 'Collection'
        css.label = "Community Service Society Records"
        css.save
        all_ldpd_content.add_member(css) unless all_ldpd_content.nil?
        css.save
      end

      bag_paths = []

      if ENV['BAG_PATH']
        bag_paths << ENV['BAG_PATH']
      end

      if ENV['BAG_LIST']
        File.readlines(ENV['BAG_LIST']).each {|line| bag_paths << line.strip }
      end

      bag_paths.each { |bag_path|

        css_bag = BagIt::Bags::CssBag.new(css, bag_path)
        css_bag.load
      }

    end

    desc "load resource objects for all the file resources in a bag"
    task :load => :environment do
      bag_path = ENV['BAG_PATH']
      override = !!ENV['OVERRIDE'] and !(ENV['OVERRIDE'] =~ /^false$/i)
      upload_dir = ActiveFedora.config.credentials[:upload_dir]
      # parse bag-info for external-id and title
      if File.basename(bag_path) == 'bag-info.txt'
        bag_path = File.dirname(bag_path)
      end
      only_data = nil
      if bag_path =~ /\/data\//
        parts = bag_path.split(/\/data\//)
        bag_path = parts[0]
        only_data = "data/#{parts[1..-1].join('')}"
      end
      derivative_options = {:override => override}
      derivative_options[:upload_dir] = upload_dir.clone.untaint if upload_dir
      bag_info = BagIt::Info.new(File.join(bag_path,'bag-info.txt'))
      raise "External-Identifier for bag is required" if bag_info.external_id.blank?
      all_ldpd_content = BagAggregator.find_by_identifier(LDPD_COLLECTIONS_ID)
      group_id = bag_info.group_id || LDPD_COLLECTIONS_ID
      Rails.logger.info "Searching for \"#{bag_info.external_id}\""
      bag_agg = BagAggregator.find_by_identifier(bag_info.external_id)
      if bag_agg.blank?
        pid = next_pid
        Rails.logger.info "NEXT PID: #{pid}"
        bag_agg = BagAggregator.new(:pid=>pid)
        bag_agg.datastreams["DC"].update_values({[:dc_identifier] => bag_info.external_id})
        bag_agg.datastreams["DC"].update_values({[:dc_title] => bag_info.external_desc})
        bag_agg.datastreams["DC"].update_values({[:dc_type] => 'Collection'})
        bag_agg.label = bag_info.external_desc
        bag_agg.save
        all_ldpd_content.add_member(bag_agg) unless all_ldpd_content.nil?
      end
      all_media_id = bag_info.external_id + "#all-media"
      all_media = ContentAggregator.find_by_identifier(all_media_id)
      if all_media.blank?
        all_media = ContentAggregator.new(:pid=>next_pid)
        all_media.datastreams["DC"].update_values({[:dc_identifier] => all_media_id})
        all_media.datastreams["DC"].update_values({[:dc_type] => 'Collection'})
        title = 'All Media From Bag at ' + bag_path
        all_media.datastreams["DC"].update_values({[:dc_title] => title})
        all_media.label = title
        all_media.save
      end

      name_parser = bag_info.id_schema
      manifest = BagIt::Manifest.new(File.join(bag_path,'manifest-sha1.txt'), name_parser)
      ctr = 0
      manifest.each_resource(true, only_data) do |rel_path, resource|
        begin
          ctr += 1
          Rails.logger.info("#{ctr} of #{bag_info.count}: Processing #{rel_path}")
          resource.derivatives!(derivative_options)
          unless resource.ids_for_outbound(:cul_member_of).include? all_media.pid
            all_media.add_member(resource)
          end
          parent_id = nil
          parent_id = (resource.container_ids.select {|x| x != all_media.pid}).first
          parent_id ||= name_parser.parent(rel_path)
          unless parent_id.blank? || (ENV['ORPHAN'] =~ /^true$/i)
            parent = ContentAggregator.find_by_identifier(parent_id)
            if parent.blank?
              parent = ContentAggregator.new(:pid=>next_pid)
              parent.datastreams["DC"].update_values({[:dc_identifier] => parent_id})
              parent.datastreams["DC"].update_values({[:dc_type] => 'InteractiveResource'})
              parent.save
              bag_agg.add_member(parent)
            end
            unless resource.ids_for_outbound(:cul_member_of).include? parent.pid
              parent.add_member(resource)
            end
          end
        rescue Exception => e
          Rails.logger.error(e.message)
          e.backtrace.each {|line| Rails.logger.error(line) }
        end
      end
      Rails.logger.info "Finished loading #{bag_path}"
    end
  end
  namespace :ricop do
    task :repair => :environment do
      bag_path = ENV['BAG_PATH']
      override = !!ENV['OVERRIDE'] and !(ENV['OVERRIDE'] =~ /^false$/i)
      upload_dir = ActiveFedora.config.credentials[:upload_dir]
      # parse bag-info for external-id and title
      if File.basename(bag_path) == 'bag-info.txt'
        bag_path = File.dirname(bag_path)
      end
      only_data = nil
      if bag_path =~ /\/data\//
        parts = bag_path.split(/\/data\//)
        bag_path = parts[0]
        only_data = "data/#{parts[1..-1].join('')}"
      end
      derivative_options = {:override => override}
      derivative_options[:upload_dir] = upload_dir.clone.untaint if upload_dir
      bag_info = BagIt::Info.new(File.join(bag_path,'bag-info.txt'))
      raise "External-Identifier for bag is required" if bag_info.external_id.blank?
      name_parser = bag_info.id_schema
      manifest = BagIt::Manifest.new(File.join(bag_path,'manifest-sha1.txt'), name_parser)
      ctr = 0
      manifest.each_resource(true, only_data) do |rel_path, resource|
        begin
          ctr += 1
          Rails.logger.info("#{ctr} of #{bag_info.count}: Processing #{rel_path}")
          resource.add_dc_identifier( name_parser.id(rel_path))
          content = resource.datastreams['content']
          content.dsLabel = content.dsLocation.split('/')[-1]
          resource.derivatives!(derivative_options)
        rescue Exception => e
          Rails.logger.error(e.message)
          e.backtrace.each {|line| Rails.logger.error(line) }
        end
      end
      Rails.logger.info "Finished repairing #{bag_path}"
    end
  end
end
