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
  namespace :lehman do
    desc 'create the project bagg'
    task :setup => :environment do
      lehman = BagAggregator.search_repo(identifier: 'apt://columbia.edu/ldpd_leh').first
      if lehman.nil?
        all_content = BagAggregator.search_repo(identifier: 'apt://columbia.edu').first
        raise 'could not find top-level storage aggregator' if all_content.nil?
        lehman = BagAggregator.new(pid: next_pid())
        lehman.label = 'The Herbert H. Lehman Collections preservation images'
        lehman.datastreams["DC"].update_values({[:dc_identifier] => ['ldpd_leh', 'apt://columbia.edu/ldpd_leh']})
        lehman.datastreams["DC"].update_values({[:dc_title] => 'The Herbert H. Lehman Collections preservation images'})
        lehman.datastreams["DC"].update_values({[:dc_type] => 'Collection'})
        lehman.add_relationship(:cul_member_of, all_content.internal_uri)
        lehman.save
      end
      @lehman = lehman.internal_uri
    end

    task :load_mods => :setup do
      paths = {}
      idp = /ldpd_leh_\d{4}_\d{4}/
      manifest = ENV['MANIFEST'] or 'lehman_mods_manifest.txt'
      open(manifest) do |blob|
        blob.each do |l|
          l.strip!
          basename = File.basename(l)
          id = (idp.match(basename))[0]
          paths[id] = l if id
        end
      end
      total = paths.size
      logger.info "#{total} ids found"
      raise "lehman bag was not set up" unless @lehman
      ctr = 0
      paths.each do |id, path|
        ctr = ctr + 1
        cagg = ContentAggregator.search_repo(identifier: id).first
        if cagg.nil?
          cagg = ContentAggregator.new(pid: next_pid())
          cagg.label = id
          cagg.datastreams["DC"].update_values({[:dc_identifier] => [id]})
          cagg.datastreams["DC"].update_values({[:dc_type] => 'InteractiveResource'})
          cagg.add_relationship(:cul_member_of, @lehman)
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
      end
    end    
  end
end
