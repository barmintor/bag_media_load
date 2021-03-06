require "rake"
require "active-fedora"
require "cul_hydra"
require "nokogiri"
require 'cul_repo_cache'
require "bag_it"
require "thread/pool"
include Cul::Repo::Constants

def next_pid
  BagIt.next_pid
end

def container_uris_for(obj,obs=false)
  r = obj.relationships(:cul_member_of)
  if obs # clean up from failed runs previous
    r += obj.relationships(:cul_obsolete_from)
  end
  r
end

def container_pids_for(obj,obs=false)
  r = container_uris_for(obj,obs) || []
  r.map {|x| x.to_s.split('/')[-1]}
end

def apt_project_id(project_id)
  id = ''
  if project_id =~ /^apt\:/
    id << project_id
  else
    if project_id =~ /^\//
      id = ('apt://columbia.edu' << project_id)
    else
      id = ('apt://columbia.edu/' << project_id)
    end
  end
  if id =~ /\/$/ and id =~ /^\//
    id = id[0...-1]
  end
  id
end

namespace :bag do
  task :info => :environment do
    puts "Task Suite to load media into Fedora at #{ActiveFedora.config.credentials[:url]}"
  end
  task :pid => :environment do
    Rails.logger.info BagIt.next_pid
  end
  task :load_fixtures  => :environment do
    ActiveFedora::Base.fedora_connection[0] ||= ActiveFedora::RubydoraConnection.new(ActiveFedora.config.credentials)
    rubydora = ActiveFedora::Base.fedora_connection[0].connection
    Dir[Rails.root.join("fixtures/cmodels/*.xml")].each {|f| Rails.logger.info rubydora.ingest :file=>open(f)}
  end
  namespace :media do
    desc "seed PRONOM data"
    task seed: :environment do
      unless PronomFormat.exists?('fmt/18')
        load "#{Rails.root}/db/seeds.rb"
      end
    end
    task reseed: :environment do
      PronomFormat.all.delete_all
      load "#{Rails.root}/db/seeds.rb"
    end
    desc "debug derivative creation"
    task :debug => :seed do
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
    task :load_css => [:seed] do

      group_id = "rbml_css"

      css = AdministrativeSet.find_by_identifier(group_id)
      if css.blank?
        all_ldpd_content = AdministrativeSet.find_by_identifier(LDPD_PROJECTS_ID)
        css_pid = next_pid
        css = AdministrativeSet.new(:pid=>css_pid)
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
    task :load => :seed do
      config = Cul::Repo::Load::Configuration.from_env
      bag_path = config.bag_path
      alg = config.checksum_alg
      pattern = config.pattern
      skip = config.offset
      override = config.override
      upload_dir = ActiveFedora.config.credentials[:upload_dir]
      # parse bag-info for external-id and title
      only_data = nil
      if bag_path =~ /\/data\//
        parts = bag_path.split(/\/data\//)
        bag_path = parts[0]
        only_data = "data/#{parts[1..-1].join('')}"
      end
      bag_info = BagIt::Info.new(bag_path)
      raise "External-Identifier for bag is required" if bag_info.external_id.blank?
      all_ldpd_content = AdministrativeSet.search_repo(identifier: LDPD_STORAGE_ID).first
      group_id = bag_info.group_id || LDPD_STORAGE_ID
      Rails.logger.info "Searching for \"#{bag_info.external_id}\""
      bag_agg = AdministrativeSet.search_repo(identifier: (bag_info.external_id)).first
      bag_agg_id = apt_project_id(bag_info.external_id)
      bag_agg ||= AdministrativeSet.search_repo(identifier: bag_agg_id).first
      if bag_agg.blank?
        # raise 'check into missing bag: ' + bag_info.external_id
        pid = next_pid
        Rails.logger.info "NEXT PID: #{pid}"
        bag_agg = AdministrativeSet.new(:pid=>pid)
        bag_agg.datastreams["DC"].update_values({[:dc_identifier] => [bag_info.external_id, bag_agg_id]})
        bag_agg.datastreams["DC"].update_values({[:dc_title] => bag_info.external_desc})
        bag_agg.datastreams["DC"].update_values({[:dc_type] => 'Collection'})
        bag_agg.label = bag_info.external_desc
        bag_agg.save
        if !all_ldpd_content.nil? and !(all_ldpd_content.members.detect {|d| d.pid.eql?(bag_agg.pid)})
          all_ldpd_content.members = all_ldpd_content.members + [bag_agg]
        end
      end
      all_media_id = bag_agg_id + "/data"
      all_media = Collection.search_repo(identifier: (all_media_id)).first
      if all_media.blank?
        all_media = Collection.new(:pid=>next_pid)
        all_media.datastreams["DC"].update_values({[:dc_identifier] => all_media_id})
        all_media.datastreams["DC"].update_values({[:dc_type] => 'Collection'})
        title = 'All Media From Bag at ' + bag_path
        all_media.datastreams["DC"].update_values({[:dc_title] => title})
        all_media.label = title
        all_media.add_relationship(:iana_describes, bag_agg.internal_uri)
        all_media.save
      end

      name_parser = bag_info.id_factory
      manifest = bag_info.manifest(alg)
      ctr = 0
      #pool = Thread.pool(2)
      manifest.each_entry(pattern || only_data || nil) do |entry|
        begin
          ctr += 1
          next if ctr < skip
          source = entry.path
          rel_path = "data/" + source.split(/\/data\//)[1..-1].join('/data/')
          Rails.logger.info("#{ctr} of #{bag_info.count}: Processing #{rel_path}")
          #pool.process(source, all_media) do |source, all_media|
            resource = manifest.find_or_create_resource(entry, nil, true)
            original_name = resource.relationships(:original_name).first
            if original_name
              original_name = original_name.object.to_s
            else
              resource.add_relationship(:original_name,entry.original_path,true)
              original_name = entry.original_path
            end
            config.object_relationships.each do |rel, vals|
              vals.each do |val|
                resource.add_relationship(rel,val, !(val.is_a? RDF::URI))
              end
            end
            container_pids = container_pids_for(resource)
            unless container_pids.include? all_media.pid
              resource.add_relationship(:cul_member_of, all_media)
            end

            # set some DC properties
            dc = resource.datastreams['DC']
            title = dc.find_by_terms(:dc_title).first
            if title.nil? || title.text =~ /^Preservation[:]? (File|Image|Recording)/
              dc.update_values([:dc_title]=>original_name.split('/')[-1])
            end
            dc_type = dc.find_by_terms(:dc_type).first
            unless dc_type.eql? entry.dc_type
              dc.update_values([:dc_type]=>entry.dc_type)
            end

            parent_id = nil
            if config.create_parent_works?
              parent_id = container_pids.select{|x| x != all_media.pid }.first
              parent_id ||= name_parser.parent(rel_path)
            end
            unless parent_id.blank?
              begin
                parent = ContentAggregator.search_repo(identifier: parent_id).first
                if parent.blank?
                  parent = ContentAggregator.new(:pid=>next_pid)
                  parent.datastreams["DC"].update_values({[:dc_identifier] => parent_id})
                  parent.datastreams["DC"].update_values({[:dc_type] => 'InteractiveResource'})
                  parent.add_relationship(:cul_member_of, bag_agg)
                  config.object_relationships.each do |rel, vals|
                    vals.each do |val|
                      parent.add_relationship(rel,val)
                    end
                  end
                  parent.save
                end
                unless container_pids.include? parent.pid
                  resource.add_relationship(:cul_member_of, parent)
                  resource.hack_rels!
                end
              rescue Exception => e
                Rails.logger.error(e.message)
                Rails.logger.error(e.backtrace.join("\n"))
              end
            end
            # since we're not calling :create, we need to call :assert_content_model
            resource.assert_content_model
            io = StringIO.new
            Cul::Foxml::Serializer.serialize_object(resource, io)
            Cul::Hydra::Fedora.repository.ingest(pid: resource.pid, file: io.string)
            # create derivatives
            resource.derivatives!(config.derivative_options,entry.derivatives)
          #end
        rescue Exception => e
          Rails.logger.error(e.message)
          Rails.logger.error(e.backtrace.join("\n"))
        end
      end
      #pool.shutdown
      Rails.logger.info "Finished loading #{bag_path}"
    end

    desc "load/migrate resource objects for all the file resources in a bag"
    task :migrate => :seed do
      bag_path = ENV['BAG_PATH']
      override = !!ENV['OVERRIDE'] and !(ENV['OVERRIDE'] =~ /^false$/i)
      upload_dir = ActiveFedora.config.credentials[:upload_dir]
      # parse bag-info for external-id and title
      only_data = nil
      if bag_path =~ /\/data\//
        parts = bag_path.split(/\/data\//)
        bag_path = parts[0]
        only_data = "data/#{parts[1..-1].join('')}"
      end
      derivative_options = {:override => override}
      derivative_options[:upload_dir] = upload_dir.clone.untaint if upload_dir
      bag_info = BagIt::Info.new(bag_path)
      raise "External-Identifier for bag is required" if bag_info.external_id.blank?
      all_ldpd_content = AdministrativeSet.search_repo(identifier: LDPD_STORAGE_ID).first
      group_id = bag_info.group_id || LDPD_STORAGE_ID
      Rails.logger.info "Searching for \"#{bag_info.external_id}\""
      bag_agg = AdministrativeSet.search_repo(identifier: (bag_info.external_id)).first
      bag_agg_id = apt_project_id(bag_info.external_id)
      bag_agg ||= AdministrativeSet.search_repo(identifier: bag_agg_id).first
      if bag_agg.blank?
        # raise 'check into missing bag: ' + bag_info.external_id
        pid = next_pid
        Rails.logger.info "NEXT PID: #{pid}"
        bag_agg = AdministrativeSet.new(:pid=>pid)
        bag_agg.datastreams["DC"].update_values({[:dc_identifier] => [bag_info.external_id, bag_agg_id]})
        bag_agg.datastreams["DC"].update_values({[:dc_title] => bag_info.external_desc})
        bag_agg.datastreams["DC"].update_values({[:dc_type] => 'Collection'})
        bag_agg.label = bag_info.external_desc
        bag_agg.save
        all_ldpd_content.add_member(bag_agg) unless all_ldpd_content.nil?
      end
      all_media_id = bag_agg_id + "/data"
      all_media = Collection.search_repo(identifier: (all_media_id)).first
      if all_media.blank?
        all_media = Collection.new(:pid=>next_pid)
        all_media.datastreams["DC"].update_values({[:dc_identifier] => all_media_id})
        all_media.datastreams["DC"].update_values({[:dc_type] => 'Collection'})
        title = 'All Media From Bag at ' + bag_path
        all_media.datastreams["DC"].update_values({[:dc_title] => title})
        all_media.label = title
        all_media.add_relationship(:iana_describes, bag_agg.internal_uri)
        all_media.save
      end

      name_parser = bag_info.id_factory
      manifest = bag_info.manifest('sha1')
      ctr = 0
      manifest.each_resource(true, only_data) do |rel_path, resource|
        begin
          ctr += 1
          Rails.logger.info("#{ctr} of #{bag_info.count}: Processing #{rel_path}")
          resource.derivatives!(derivative_options)
          container_pids = container_pids_for(resource)
          unless container_pids.include? all_media.pid
            resource.add_relationship(:cul_member_of, all_media)
            begin
              resource.save
            rescue
              Rails.logger.warn("could not add #{resource.pid} to all-media agg #{all_media.pid}")
            end
          end
          parent_id = nil
          parent_id = container_pids.select{|x| x != all_media.pid }.first
          parent_id ||= name_parser.parent(rel_path)
          unless parent_id.blank? || (ENV['ORPHAN'] =~ /^true$/i)
            parent = ContentAggregator.search_repo(identifier: parent_id).first
            if parent.blank?
              parent = ContentAggregator.new(:pid=>next_pid)
              parent.datastreams["DC"].update_values({[:dc_identifier] => parent_id})
              parent.datastreams["DC"].update_values({[:dc_type] => 'InteractiveResource'})
              parent.add_relationship(:cul_member_of, bag_agg)
              parent.save
            end
            unless container_pids.include? parent.pid
              resource.add_relationship(:cul_member_of, parent)
              resource.hack_rels!
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
    task :clean => :environment do 
      manifest = ENV['manifest']
      entries = []
      open(manifest) do |blob|
        blob.each {|line| entries << line.split[1].strip}
      end
      ids = entries.map{|entry| 'apt://columbia.edu/prd.russianpages/' + entry}
      ALL_MEDIA = 'ldpd:144192'
      ids.each do |resource_id|
        resource = GenericResource.search_repo(identifier: resource_id).first
        if resource
          p "Found #{resource_id} at #{resource.pid}"
        else
          p "Missing resource for #{resource_id}"
        end
        containers = resource.containers
        containers.each do |container|

          dc = container.datastreams['DC']
          if container.pid == ALL_MEDIA || dc.term_values(:dc_identifier).include?('prd.russianpages#all-media')
            p 'Skipping all-media'
            next
          end
          desc = container.nil? ? nil : container.datastreams['descMetadata']
          if desc.nil? || desc.new?
            if container.pid != ALL_MEDIA
              resource.remove_relationship(:cul_member_of, container)
              resource.save
              container.delete
              break
            end
          end
        end
        break
      end
    end 
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
      name_parser = bag_info.id_factory
      manifest = bag_info.manifest('sha1')
      ctr = 0
      manifest.each_resource(true, only_data) do |rel_path, resource|
        begin
          ctr += 1
          Rails.logger.info("#{ctr} of #{bag_info.count}: Processing #{rel_path}")
          resource.set_dc_identifier( name_parser.id(rel_path))
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
  namespace :jay do
    task :jp2rels => :environment do
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
      name_parser = bag_info.id_factory
      manifest = BagIt::Manifest.new(File.join(bag_path,'manifest-sha1.txt'), name_parser)
      ctr = 0
      manifest.each_resource(true, only_data) do |rel_path, resource|
        begin
          ctr += 1
          Rails.logger.info("#{ctr} of #{bag_info.count}: Processing #{rel_path}")
          if resource.datastreams["zoom"]
            ds_c = resource.datastreams["content"]
            ds_z = resource.datastreams["zoom"]
            resource.rels_int.add_relationship(ds_c, :foaf_zooming, ds_z)
            resource.rels_int.serialize!
            resource.save
          end
        rescue Exception => e
          Rails.logger.error(e.message)
          e.backtrace.each {|line| Rails.logger.error(line) }
        end
      end
      Rails.logger.info "Finished repairing #{bag_path}"
    end
  end
end
