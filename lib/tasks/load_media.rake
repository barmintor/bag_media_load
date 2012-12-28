require "active-fedora"
require "cul_scv_hydra"
require "nokogiri"
require "bag"
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

namespace :bag do
  task :pid do
    ActiveFedora::Base.fedora_connection[0] ||= ActiveFedora::RubydoraConnection.new(ActiveFedora.config.credentials)
    rubydora = ActiveFedora::Base.fedora_connection[0].connection
    puts rubydora.next_pid(:namespace=>'ldpd')
  end
  task :load_fixtures do
    ActiveFedora::Base.fedora_connection[0] ||= ActiveFedora::RubydoraConnection.new(ActiveFedora.config.credentials)
    rubydora = ActiveFedora::Base.fedora_connection[0].connection
    Dir[Rails.root.join("fixtures/cmodels/*.xml")].each {|f| puts rubydora.ingest :file=>open(f)}
  end
  namespace :media do
    desc "debug derivative creation"
    task :debug => :environment do
      rpath = '/fstore/archive/ldpd/preservation/lindquist/data/Lindquist_box_OS/burke_lindq_OS_1907v.tif'
      resource = GenericResource.find_by_source(rpath)
      puts "Found image at #{resource.pid}"
      resource.migrate!
      resource.derivatives!
      resource.datastreams.each_key do |key|
        ds = resource.datastreams[key]
        puts "#{resource.pid}##{ds.dsid}.dsSize : #{ds.dsSize}"
      end
    end
    desc "load resource objects for all the file resources in a bag"
    task :load => :environment do
      bag_path = ENV['BAG_PATH']
      # parse bag-info for external-id and title
      if File.basename(bag_path) == 'bag-info.txt'
        bag_path = File.dirname(bag_path)
      end
      
      bag_info = Bag::Info.new(File.join(bag_path,'bag-info.txt'))
      raise "External-Identifier for bag is required" if bag_info.external_id.blank?
      all_ldpd_content = BagAggregator.find_by_identifier(LDPD_COLLECTIONS_ID)
      group_id = bag_info.group_id || LDPD_COLLECTIONS_ID
      puts "Searching for \"#{bag_info.external_id}\""
      bag_agg = BagAggregator.find_by_identifier(bag_info.external_id)
      if bag_agg.blank?
        bag_agg = BagAggregator.new(:namespace=>'ldpd')
        bag_agg.dc.identifier = bag_info.external_id
        bag_agg.dc.title = bag_info.external_desc
        bag_agg.dc.dc_type = 'Collection'
        bag_agg.label = bag_info.external_desc
        bag_agg.save
        all_ldpd_content.add_member(bag_agg) unless all_ldpd_content.nil?
      end
      all_media_id = bag_info.external_id + "#all-media"
      all_media = ContentAggregator.find_by_identifier(all_media_id)
      if all_media.blank?
        all_media = ContentAggregator.new(:namespace=>'ldpd')
        all_media.dc.identifier = all_media_id
        all_media.dc.dc_type = 'Collection'
        title = 'All Media From Bag at ' + bag_path
        all_media.dc.title = title
        all_media.label = title
        all_media.save
      end

      manifest = Bag::Manifest.new(File.join(bag_path,'manifest-sha1.txt'))
      manifest.each_resource do |resource|
        resource.derivatives!(:override=>true)
        unless resource.ids_for_outbound(:cul_member_of).include? all_media.pid
          all_media.add_member(resource)
        end
      end
      puts "INFO: Finished loading #{bag_path}"
    end
  end
end
