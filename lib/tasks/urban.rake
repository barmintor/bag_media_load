require "rake"
require "active-fedora"
require "cul_scv_hydra"
require "nokogiri"
require "bag_it"
LDPD_COLLECTIONS_ID = 'http://libraries.columbia.edu/projects/aggregation'
LDPD_STORAGE_ID = 'apt://columbia.edu'
URBAN_PROJECT_ID = "http://www.columbia.edu/cu/lweb/eresources/archives/rbml/urban/"
URBAN_STORAGE_ID = LDPD_STORAGE_ID + '/rbml.urban'
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
  namespace :urban do
    desc 'create the project bagg'
    task :setup => :environment do
      urban_project =  BagAggregator.search_repo(identifier: URBAN_PROJECT_ID).first
      urban_bag = BagAggregator.search_repo(identifier: URBAN_STORAGE_ID).first
      if urban_bag.nil?
        all_content = BagAggregator.search_repo(identifier: LDPD_STORAGE_ID).first
        raise 'could not find top-level storage aggregator' if all_content.nil?
        urban_bag = BagAggregator.new(pid: next_pid())
        urban_bag.datastreams["DC"].update_values({[:dc_identifier] => ['rbml.urban', URBAN_STORAGE_ID]})
        urban_bag.datastreams["DC"].update_values({[:dc_type] => 'Collection'})
        urban_bag.add_relationship(:cul_member_of, all_content.internal_uri)
        urban_bag.save
      end
      if urban_project.nil?
        all_content = BagAggregator.search_repo(identifier: LDPD_COLLECTIONS_ID).first
        raise 'could not find top-level projects aggregator' if all_content.nil?
        urban_project = BagAggregator.new(pid: next_pid())
        urban_project.datastreams["DC"].update_values({[:dc_identifier] => [URBAN_PROJECT_ID, 'ldpd.urban']})
        urban_project.datastreams["DC"].update_values({[:dc_type] => 'Collection'})
        urban_project.add_relationship(:cul_member_of, all_content.internal_uri)
        urban_project.save
      end
      @urban_bag = urban_bag.internal_uri
      @urban_project = urban_project.internal_uri
    end

    task :load => :setup do
      raise "urban bag was not set up" unless @urban_bag
      raise "urban project was not set up" unless @urban_project
      manifest = ENV['MANIFEST']
      manifest = open(ENV['MANIFEST']) {|x| x.read}
      manifest = JSON.parse(manifest.gsub('=>',':'))
      total = manifest.size
      logger.info "#{total} ids found"
      ctr = 0
      manifest.each do |id, v|
        ctr = ctr + 1
        cagg = ContentAggregator.search_repo(identifier: id).first
        if cagg.nil?
          cagg = ContentAggregator.new(pid: next_pid())
          cagg.label = id
          cagg.datastreams["DC"].update_values({[:dc_identifier] => [id]})
          cagg.datastreams["DC"].update_values({[:dc_type] => 'InteractiveResource'})
          if v['type'] == 'asset'
            cagg.add_relationship(:cul_member_of, @urban_bag)
          else
            cagg.add_relationship(:cul_member_of, @urban_project)
          end
          cagg.save
          logger.info "created #{cagg.pid} for #{id} #{ctr} of #{total}"
        else
          logger.info "found #{cagg.pid} for #{id} #{ctr} of #{total}"
        end
        descMetadata = cagg.datastreams['descMetadata']
        if descMetadata.new?
          descMetadata.mimeType = 'text/xml'
          open(v['mods']) {|blob| descMetadata.content = blob.read}
          cagg.save
          logger.info "created #{cagg.pid}/descMetadata for #{id} #{ctr} of #{total}"
        end
      end
    end    
    task :structure => :setup do
      raise "urban bag was not set up" unless @urban_bag
      raise "urban project was not set up" unless @urban_project
      manifest = ENV['MANIFEST']
      manifest = open(ENV['MANIFEST']) {|x| x.read}
      manifest = JSON.parse(manifest.gsub('=>',':'))
      total = manifest.size
      logger.info "#{total} ids found"
      ctr = 0
      manifest.each do |id, v|
        ctr = ctr + 1
        cagg = ContentAggregator.search_repo(identifier: id).first
        if cagg.nil?
          logger.error "could not find  #{id} #{ctr} of #{total}"
        else
          logger.info "found #{cagg.pid} for #{id} #{ctr} of #{total}"
          members = v['members']
          titles = []
          type = v['type']
          members.each_with_index do |member, ix|
            gr = GenericResource.search_repo(identifier: member).first
            if gr
              gr.add_relationship(:cul_member_of,cagg.internal_uri)
              gr.save
            end
            if type == 'item'
              suffix = /(\d{2})\.tif$/.match(member)[1]
              sc = ContentAggregator.search_repo(identifier: id + suffix).first
              title = "Item #{suffix.to_i}"
              if sc
                title = sc.to_solr["title_si"]
              end
              titles << title
            else
              titles << "Item #{ix.to_s}"
            end
          end
          if members.length > 1
            sm = cagg.datastreams['structMetadata']
            unless sm.new? # restructure
              sm.content = sm.class.xml_template
            end
            sm.type = 'logical'
            sm.label = 'Items'
            members.each_with_index do |member, ix|
              sm.create_div_node(nil, {:order=>ix.to_s, :label=>titles[ix], :contentids=>member})
            end
            cagg.save
            logger.info "structured #{cagg.pid} for #{id} #{ctr} of #{total}"
          end
        end
      end
    end    
  end
end
