require "rake"
require "active-fedora"
require "cul_scv_hydra"
require "nokogiri"
require "bag_it"
ALL_PROJECTS_ID = 'http://libraries.columbia.edu/projects/aggregation'
ALL_STORAGE_ID = 'apt://columbia.edu'
PROJECT_ID = "http://universityseminars.columbia.edu"
STORAGE_ID = ALL_STORAGE_ID + '/rbml.usem'
class Fake
  attr_accessor :pid
  def initialize(pid, isNew=false)
    @pid = pid
    @isNew = isNew
  end
  def new_record?
    @isNew
  end
  def connection
    @connection ||= ActiveFedora::RubydoraConnection.new(ActiveFedora.fedora_config.credentials)
  end    
  def repository
    @repository ||= connection.connection
  end
  def spawn(pid)
    s = Fake.new(pid)
    s.connection= connection
    s.repository= repository
    s
  end
  protected
  def connection=(connection); @connection = connection; end
  def repository=(repo); @repository = repo; end
end

def next_pid
  BagIt.next_pid
end

def ds_at(fedora_uri, d_obj = nil)
  p = fedora_uri.split('/')
  d_obj = d_obj.nil? ? Fake.new(p[1]) : d_obj.spawn(p[1])
  Rubydora::Datastream.new(d_obj, p[2])
end


def logger
  Rails.logger
end

namespace :util do
  namespace :usem do
    def load_objects(obj_path)
      objects = []
      open(obj_path) do |blob|
        blob.each do |line|
          line.strip!
          objects << line
        end
      end
      objects
    end

    def load_assets(assets_path)
      lines = load_objects(assets_path)
      assets = lines.collect do |line|
        path = line.split(' ')[1..-1].join(' ')
        "#{STORAGE_ID}/#{path}"
      end
      assets
    end

    def map_assets(assets)
      mapped = {}
      assets.each do |asset|
        file_id = asset.sub("#{STORAGE_ID}/data/11152013/USEMS_Archive/",'')
        file_id = file_id.sub("#{STORAGE_ID}/data/04252014/university_seminars/",'')
        puts "file_id: #{file_id}"
        obj_id = 'ldpd.usem/' + file_id[0...file_id.rindex('.')]
        mapped[obj_id] = asset
      end
      mapped
    end
  	task :init => :environment do
      storage = BagAggregator.new(pid: 'ldpd:163964')
      dc = storage.datastreams['DC']
      dc.update_values({[:dc_identifier] => ['rbml.usem', 'apt://columbia.edu/rbml.usem']})
      dc.update_values({[:dc_type] => 'Collection'})
      dc.update_values({[:dc_title] => 'Files from University Seminars'})
      dc.content_will_change!
      storage.add_relationship(:cul_member_of,'info:fedora/cul-system:archives')
      storage.save
      data = ContentAggregator.new(pid: 'ldpd:163966')
      dc = data.datastreams['DC']
      dc.update_values({[:dc_identifier] => ['apt://columbia.edu/rbml.usem/data']})
      dc.update_values({[:dc_type] => 'FileSystem'})
      dc.update_values({[:dc_title] => 'All Media Files from University Seminars'})
      dc.content_will_change!
      data.add_relationship(:cul_member_of,'info:fedora/ldpd:163964')
      data.save
      @storage = storage.internal_uri
      @data = data.internal_uri
  	end
    desc 'create the project bagg'
    task :setup => :environment do
      project =  BagAggregator.search_repo(identifier: PROJECT_ID).first
      storage = BagAggregator.search_repo(identifier: STORAGE_ID).first
      if storage.nil?
        all_content = BagAggregator.search_repo(identifier: ALL_STORAGE_ID).first
        raise 'could not find top-level storage aggregator' if all_content.nil?
        storage = BagAggregator.new(pid: next_pid())
        storage.datastreams["DC"].update_values({[:dc_identifier] => ['rbml.usem', STORAGE_ID]})
        storage.datastreams["DC"].update_values({[:dc_type] => 'Collection'})
        storage.add_relationship(:cul_member_of, all_content.internal_uri)
        storage.save
      end
      if project.nil?
        all_content = BagAggregator.search_repo(identifier: ALL_PROJECTS_ID).first
        raise 'could not find top-level projects aggregator' if all_content.nil?
        project = BagAggregator.new(pid: next_pid())
        project.datastreams["DC"].update_values({[:dc_identifier] => [PROJECT_ID, 'ldpd.usem']})
        project.datastreams["DC"].update_values({[:dc_type] => 'Collection'})
        project.add_relationship(:cul_member_of, all_content.internal_uri)
        project.save
      end
      @storage = storage.internal_uri
      @project = project.internal_uri
    end

    task :load => :setup do
      objects = load_objects(ENV['OBJECTS'])
      assets = load_assets(ENV['ASSETS'])
      raise "project bag was not set up" unless @project
      raise "storage bag was not set up" unless @storage
      map = map_assets(assets)
      # no ids in data, so contrive one
      ctr = 0
      total = objects.size
      objects.each do |mods|
        ctr += 1
        bn = File.basename(mods)

        file_id = mods.sub(/_mods.xml$/,'')
        file_id.sub!('/Users/ba2213/Github/cul/usem_mods/mods/','')
        obj_id = file_id[0...file_id.rindex('.')]
        obj_id = 'ldpd.usem/' + obj_id
        if ctr < 33511
          puts "#{ctr} of #{total}: skipping #{obj_id}"
          next
        end
        puts "#{ctr} of #{total}: #{obj_id} ->"
        puts '    ' + map[obj_id]
#        object = ContentAggregator.search_repo(identifier: obj_id.sub('%20','?')).first
        object = ContentAggregator.search_repo(identifier: (obj_id.gsub(' ','?') || obj_id)).first
        unless object

          object = ContentAggregator.new(pid: next_pid())
          object.datastreams["DC"].update_values({[:dc_identifier] => [obj_id]})
          object.datastreams["DC"].update_values({[:dc_type] => 'InteractiveResource'})
          object.add_relationship(:cul_member_of, @project)
        end
        unless object.relationships(:publisher).include? "info:fedora/project:usem"
          object.add_relationship(:publisher, "info:fedora/project:usem")
        end
        object.save          
        if object
          ng_xml = open(mods){ |f| Nokogiri::XML(f) }
          ds = object.datastreams['descMetadata']
          ds.ng_xml = ng_xml
          ds.content_will_change!
          label = Array(ds.term_values(:title_display)).first || obj_id
          label = label[0...255] if label.length > 255
          object.label = label
          object.save
          Array(map[obj_id]).each do |asset_id|
            asset = GenericResource.search_repo(identifier: (asset_id.gsub(' ','?') || asset_id)).first
            if asset
              asset.add_relationship(:cul_member_of, object.internal_uri)
              asset.add_relationship(:publisher, "info:fedora/project:usem")
              if asset_id =~ /\.pdf/
                unless asset.datastreams["DC"].term_values(:dc_type).include? 'Text'
                  asset.datastreams["DC"].update_values({[:dc_type] => 'Text'})
                  asset.datastreams["DC"].content_will_change!
                end
              end
              asset.save
            end
          end
        end
      end
    end
    task :structure => :setup do
    end    
  end
end
