require "rake"
require "active-fedora"
require "cul_scv_hydra"
require "nokogiri"
require "bag_it"
LDPD_COLLECTIONS_ID = 'http://libraries.columbia.edu/projects/aggregation'
LDPD_STORAGE_ID = 'apt://columbia.edu'
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
  namespace :biggert do
    desc 'create the project bagg'
    task :setup => :environment do
      biggert = BagAggregator.search_repo(identifier: 'http://www.columbia.edu/cgi-bin/cul/resolve?clio7887951').first
      if biggert.nil?
        all_content = BagAggregator.search_repo(identifier: LDPD_COLLECTIONS_ID).first
        raise 'could not find top-level collections aggregator' if all_content.nil?
        biggert = BagAggregator.new(pid: next_pid())
        biggert.label = 'The Biggert Collection of Architectural Vignettes on Commercial Stationery'
        biggert.datastreams["DC"].update_values({[:dc_identifier] => ['ave_biggert', 'http://www.columbia.edu/cgi-bin/cul/resolve?clio7887951']})
        biggert.datastreams["DC"].update_values({[:dc_title] => 'The Biggert Collection of Architectural Vignettes on Commercial Stationery'})
        biggert.datastreams["DC"].update_values({[:dc_type] => 'Collection'})
        biggert.add_relationship(:cul_member_of, all_content.internal_uri)
        biggert.save
      end
      @biggert = biggert.internal_uri
    end

    task :load_mods => :setup do
      paths = {}
      idp = /ave_biggert_\d{5}/
      manifest = ENV['MODS']
      open(manifest) do |blob|
        blob.each do |l|
          l.strip!
          basename = File.basename(l)
          id = (idp.match(basename))[0]
          paths[id] = l if id
        end
      end
      asset_ids = {}
      manifest = ENV['ASSETS']
      open(manifest) do |blob|
        blob.each do |l|
          l.strip!
          parts = l.split(',')
          if parts[1] =~ /apt/
          	basename = parts[1].split('/')[-1]
            if (match = idp.match(basename))
              id = match[0]
              asset_ids[id] ||= []
              asset_ids[id] << {pid: parts[0].split('/')[-1], src: parts[1]}
            end
          end
        end
      end

      total = paths.size
      logger.info "#{total} ids found"
      raise "biggert bag was not set up" unless @biggert
      ctr = 0
      paths.each do |id, path|
        ctr = ctr + 1
        cagg = ContentAggregator.search_repo(identifier: id).first
        if cagg.nil?
          cagg = ContentAggregator.new(pid: next_pid())
          cagg.label = id
          cagg.datastreams["DC"].update_values({[:dc_identifier] => [id]})
          cagg.datastreams["DC"].update_values({[:dc_type] => 'InteractiveResource'})
          cagg.add_relationship(:cul_member_of, @biggert)
          cagg.save
          logger.info "created #{cagg.pid} for #{id} #{ctr} of #{total}"
        else
          logger.info "found #{cagg.pid} for #{id} #{ctr} of #{total}"
        end
        descMetadata = cagg.datastreams['descMetadata']
        if descMetadata.new?
          descMetadata.mimeType = 'text/xml'
          open(path) {|blob| descMetadata.content = blob.read}
          cagg.save
          logger.info "created #{cagg.pid}/descMetadata for #{id} #{ctr} of #{total}"
        end
        assets = asset_ids[id]
        if assets and assets.first
          assets.each do |asset|
            gr = GenericResource.find(asset[:pid])
            unless gr.datastreams["DC"].term_values(:dc_type) == ['StillImage']
              gr.datastreams["DC"].update_values({[:dc_type] => 'StillImage'})
            end
            unless gr.relationships(:cul_member_of).collect {|m| m.to_s}.include? cagg.internal_uri
              gr.add_relationship(:cul_member_of, cagg.internal_uri)
            end
            gr.save
          end
          logger.info "associated #{cagg.pid} with #{assets.size} child resources for #{id} #{ctr} of #{total}"
          if assets.size > 1
            recto = assets.select{|a| a[:src] =~ /r\.tif$/}.first
            verso = assets.select{|a| a[:src] =~ /v\.tif$/}.first
            ds = cagg.datastreams['structMetadata']
            ds.recto_verso!
            ds.recto['CONTENTIDS']=recto[:src]
            ds.verso['CONTENTIDS']=verso[:src]
            cagg.save
            logger.info "structured #{cagg.pid} #{ctr} of #{total}"
          end
        end
      end
    end    
  end
end
