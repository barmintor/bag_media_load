require "rake"
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

def rubydora
  ActiveFedora::Base.fedora_connection[0] ||= ActiveFedora::RubydoraConnection.new(ActiveFedora.config.credentials)
  ActiveFedora::Base.fedora_connection[0].connection
end

def next_pid
  Bag.next_pid
end

namespace :bag do
  task :pid do
    puts Bag.next_pid
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
    desc "load CSS media"
    task :load_css => [:environment] do
      bag_path = ENV['BAG_PATH']
      # parse bag-info for external-id and title
      if File.basename(bag_path) == 'bag-info.txt'
        bag_path = File.dirname(bag_path)
      end

      bag_info = Bag::Info.new(File.join(bag_path,'bag-info.txt'))
      if bag_info.external_id.blank?
        bag_info.external_id = bag_path.split('/')[-1]
      end

      bag_id = bag_info.external_id

      all_ldpd_content = BagAggregator.find_by_identifier(LDPD_COLLECTIONS_ID)

      group_id = "rbml_css"

      css = BagAggregator.find_by_identifier(group_id)
      if css.blank?
        css_pid = next_pid
        css = BagAggregator.new(:pid=>css_pid)
        css.dc.identifier = group_id
        css.dc.title = "Community Service Society Records"
        css.dc.dc_type = 'Collection'
        css.label = bag_info.external_desc
        css.save
        all_ldpd_content.add_member(css) unless all_ldpd_content.nil?
        css.save
      end  
      
      puts "Searching for \"#{bag_info.external_id}\""
      bag_agg = ContentAggregator.find_by_identifier(bag_info.external_id)
      if bag_agg.blank?
        pid = next_pid
        puts "NEXT PID: #{pid}"
        bag_agg = ContentAggregator.new(:pid=>pid)
        bag_agg.dc.identifier = bag_info.external_id
        bag_agg.dc.title = bag_info.external_desc
        bag_agg.dc.dc_type = 'Collection'
        bag_agg.label = bag_info.external_desc
        bag_agg.descMetadata.content = open(File.join(bag_path,'data', bag_id, "#{bag_id}_mods.xml"))
        bag_agg.save
        css.add_member(bag_agg) unless css.nil?
      end

      recto_path = File.join(bag_path,'data', bag_id, "#{bag_id}r.tif")
      verso_path = File.join(bag_path,'data', bag_id, "#{bag_id}v.tif")
      if File.file? recto_path
        recto = Bag::Manifest.find_or_create_resource(recto_path)
        recto.derivatives!
        tech_md_path = recto_path + ".fits.xml"
        tech_md_sources = Bag::Manifest.sources(tech_md_path)
        tech_md = recto.create_datastream(ActiveFedora::Datastream, "techMetadata",
                                         :controlGroup => 'M', :dsLabel => tech_md_sources[0])
        tech_md.content = open(tech_md_path)
        recto.add_datastream(tech_md)
        recto.save
        bag_agg.add_member(recto)
        recto.save
      end

      if File.file? verso_path
        verso = Bag::Manifest.find_or_create_resource(verso_path)
        verso.derivatives!
        tech_md_path = verso_path + ".fits.xml"
        tech_md_sources = Bag::Manifest.sources(tech_md_path)
        tech_md = verso.create_datastream(ActiveFedora::Datastream, "techMetadata",
                                         :controlGroup => 'M', :dsLabel => tech_md_sources[0])
        tech_md.content = open(tech_md_path)
        verso.add_datastream(tech_md)
        verso.save
        bag_agg.add_member(verso)
        verso.save
      end
      # create_datastream(ActiveFedora::Datastream, dsid, :controlGroup => 'M', :mimeType=>mimeType, :dsLabel=>ds_label, :versionable=>false)
      puts "INFO: Finished loading #{bag_path}"
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
        pid = next_pid
        puts "NEXT PID: #{pid}"
        bag_agg = BagAggregator.new(:pid=>pid)
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
        all_media = ContentAggregator.new(:pid=>next_pid)
        all_media.dc.identifier = all_media_id
        all_media.dc.dc_type = 'Collection'
        title = 'All Media From Bag at ' + bag_path
        all_media.dc.title = title
        all_media.label = title
        all_media.save
      end

      manifest = Bag::Manifest.new(File.join(bag_path,'manifest-sha1.txt'))
      manifest.each_resource do |resource|
        resource.derivatives!(:override=>false)
        unless resource.ids_for_outbound(:cul_member_of).include? all_media.pid
          all_media.add_member(resource)
        end
      end
      puts "INFO: Finished loading #{bag_path}"
    end
  end
end
