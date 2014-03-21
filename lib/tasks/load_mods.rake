require "rake"
require "active-fedora"
require "cul_scv_hydra"
require "nokogiri"
require "bag_it"
require "open-uri"
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

def remove_member(member, container)
  member.remove_relationship(:cul_member_of, container.internal_uri)
  member.datastreams["RELS-EXT"].content_will_change!
  member.save
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
  namespace :tree do
    desc "put prd_fish into custord"
    task :prd_fish => :environment do
      custord = BagAggregator.find_by_identifier('prd.custord')
      all = BagAggregator.find_by_identifier('http://libraries.columbia.edu/projects/aggregation')
      ids = ['prd.urashima.001', 'prd.urashima.002', 'prd.shurin.001']

      ids.each do |id|
        Rails.logger.info "Re-parenting #{id}"
        obj = ContentAggregator.find_by_identifier(id)
        unless obj.blank?
          custord.add_member(obj)
          remove_member(obj, all)
        else
          Rails.logger.info "No object for #{id}"
        end
      end
    end
  end

  namespace :mods do
    desc "attach some MODS to objects"
    task :prd_fish => :environment do
      ids = ['prd.urashima.001', 'prd.urashima.002', 'prd.shurin.001']
      base_path = 'https://raw.githubusercontent.com/cul/urashima_mods/master/data/'
      ids.each do |id|
        Rails.logger.info "Loading #{id}"
        mods_path = base_path + id + '.xml'
        uri = URI(mods_path)
        ssl_opts = {:use_ssl => true, :ssl_version => :SSLv3, :verify_mode => OpenSSL::SSL::VERIFY_PEER}
        Net::HTTP.start(uri.host, uri.port, ssl_opts) do |http|
          mods = http.get(mods_path)
          obj = ContentAggregator.find_by_identifier(id)
          unless obj.blank?
            obj.datastreams['descMetadata'].content = mods.body
            obj.save
            Rails.logger.info "Finished loading #{id} from #{mods_path}"
          else
            Rails.logger.info "No object for #{id}"
          end
        end
      end
    end
  end
end