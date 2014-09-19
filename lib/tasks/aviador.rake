require "rake"
require "active-fedora"
require "cul_scv_hydra"
require "nokogiri"
require "bag_it"
require 'thread/pool'
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

def load_objects(dir)
  objects = []
  open(File.join(dir, 'object-manifest.txt')) do |blob|
    blob.each do |line|
      line.strip!
      objects << line
    end
  end
  objects = objects.collect do |obj_path|
    obj = open(File.join(dir,obj_path)) {|f| JSON.load(f)}
    obj['descMetadata'] = File.join(dir,obj['descMetadata'])
    if obj['structMetadata']
      obj['structMetadata'] = File.join(dir,obj['structMetadata'])
    end
    obj['members'].each do |member|
      member['descMetadata'] = File.join(dir,member['descMetadata'])
    end
    obj
  end
end

namespace :util do
  namespace :aviador do
    desc 'create the project bagg'
    task :setup => :environment do
      all_collections = BagAggregator.search_repo(identifier: LDPD_COLLECTIONS_ID).first
      raise "Could not find LDPD collections aggregator at #{LDPD_COLLECTIONS_ID}" unless all_collections
      ferriss = BagAggregator.search_repo(identifier: 'ldpd.ferriss').first
      unless ferriss
        ids = ['ldpd.ferriss','http://library.columbia.edu/indiv/avery/da/collections/ferriss.html']
        title = "Content for the Hugh Ferriss Architectural Drawings"
        ferriss = BagAggregator.new(pid: next_pid())
        ferriss.label = title
        ferriss.datastreams["DC"].update_values({[:dc_title] => title})
        ferriss.datastreams["DC"].update_values({[:dc_identifier] => ids})
        ferriss.datastreams["DC"].update_values({[:dc_type] => 'Collection'})
        ferriss.add_relationship(:cul_member_of, all_collections.internal_uri)
        ferriss.save
      end
      @ferriss = ferriss.internal_uri
      ggva = BagAggregator.search_repo(identifier: 'ldpd.ggva').first
      unless ggva
        ids = ['ldpd.ggva','http://www.columbia.edu/cgi-bin/cul/resolve?clio4278328']
        title = "Content for the Greene & Greene Project"
        ggva = BagAggregator.new(pid: next_pid())
        ggva.label = title
        ggva.datastreams["DC"].update_values({[:dc_title] => title})
        ggva.datastreams["DC"].update_values({[:dc_identifier] => ids})
        ggva.datastreams["DC"].update_values({[:dc_type] => 'Collection'})
        ggva.add_relationship(:cul_member_of, all_collections.internal_uri)
        ggva.save
      end
      @ggva = ggva.internal_uri
    end
    task :load_mods => :setup do
      dir = ENV['aviador_dir']
      raise "Aviador data root directory param is required 'aviador_dir'" unless dir
      objects = load_objects(dir)
      puts "loaded #{objects.length} objects"
      raise "no ferriss BagAggregator" unless @ferriss
      raise "no ggva BagAggregator" unless @ggva
      logger = Rails.logger
      logger.level = Logger::INFO
      logger.info "processing #{objects.length} aviador objects"
      pool = Thread.pool(4)
      logger.info "allocated a 4 thread pool"
      ctr = 0
      total = objects.length
      objects.each do |object|
        ctr = ctr + 1
        ng_xml = open(object["descMetadata"]) { |f| Nokogiri::XML(f) }
        title = ng_xml.xpath('/mods:mods/mods:titleInfo/mods:title', mods:"http://www.loc.gov/mods/v3").first.text
        object['title'] = title
        object['members'].each do |member|
          ng_xml = open(member["descMetadata"]) { |f| Nokogiri::XML(f) }
          title = ng_xml.xpath('/mods:mods/mods:titleInfo/mods:title', mods:"http://www.loc.gov/mods/v3").first
          member['title'] = (title.nil? ? member["id"] : title.text)
        end
        object['ctr'] = ctr
        object['total'] = total
        logger.info "#{ctr}/#{total}: Starting #{object['id']}"
        obj = object
        aggs = {'ldpd.ferriss'=>@ferriss, 'ldpd.ggva'=>@ggva}
        #pool.process(object, {'ldpd.ferriss'=>@ferriss, 'ldpd.ggva'=>@ggva}, logger) do |obj, aggs, logger|
          begin
            cagg = ContentAggregator.search_repo(identifier: obj['id']).first
            unless cagg
              cagg = ContentAggregator.new(pid: next_pid())
              cagg.label = obj['title'].length > 255 ? obj['title'][0...255] : obj['title']
              cagg.datastreams["DC"].update_values({[:dc_title] => obj['title']})
              cagg.datastreams["DC"].update_values({[:dc_identifier] => obj['id']})
              cagg.datastreams["DC"].update_values({[:dc_type] => 'InteractiveResource'})
              aggs.each do |k,v|
                if obj['id'].start_with? k
                  cagg.add_relationship(:cul_member_of, v)
                end
              end
              cagg.save
              logger.info "#{obj['ctr']}/#{obj['total']}: Created #{cagg.pid} for #{obj['id']}"
            else
              logger.info "#{obj['ctr']}/#{obj['total']}: Found #{cagg.pid} for #{obj['id']}"
            end
            if obj['structMetadata']
              sm = cagg.datastreams['structMetadata']
              if (sm.new? or obj['id'].eql? 'ldpd_ferriss_NYDA87-F85') and obj['structMetadata']
                open(obj['structMetadata']) {|f| sm.content = f.read}
                logger.info "#{obj['ctr']}/#{obj['total']}: Structured #{cagg.pid}"
              end
            end
            dm = cagg.datastreams['descMetadata']
            open(obj['descMetadata']) {|f| dm.content = f.read}
            cagg.save
            logger.info "#{obj['ctr']}/#{obj['total']}: Processing #{obj['members'].length} members of #{cagg.pid}"
            obj['members'].each do |member|
              gr = GenericResource.search_repo(identifier: member['id']).first
              if gr
                gr.label = (member['title'].length > 255 ? member['title'][0...255] : member['title'])
                dc = gr.datastreams['DC']
                dc.content
                dc.update_values({[:dc_title] => member['title']})
                if gr.datastreams['content'].dsLocation =~ /\.tif/i
                  dc.update_values({[:dc_type] => ['StillImage']})
                end
                dc.content= dc.to_xml
                dc.content_will_change!
                dc.save
                gr.add_relationship(:cul_member_of, cagg.internal_uri)
                gr.save
                dm = gr.datastreams['descMetadata']
                open(member['descMetadata']) {|f| dm.content = f.read}
                gr.save
              end
            end
            logger.info "#{obj['ctr']}/#{obj['total']}: Finished #{cagg.pid}"
          rescue Exception => e
            logger.error "#{e.message}\n" + e.backtrace.join("\n")
            raise e
          end
        #end
      end
      pool.wait_done
      pool.shutdown
    end
    task :move => :environment do
      path = ENV['list']
      raise "Can't process moves without a list of moves" unless path
      cmds = []
      open(path) do |f|
        f.each {|l| l.strip!; cmds << l}
      end
      cmds.each do |cmd|
        parts = cmd.split(' ')
        old_id = "apt://columbia.edu/avery.ggva/#{parts[1]}"
        new_ids = ["apt://columbia.edu/avery.ggva/#{parts[2]}"]
        new_ids << File.basename(parts[2])[0...-4]
        gr = GenericResource.search_repo(identifier: old_id).first
        if gr
          content = gr.datastreams['content']
          dsl = content.dsLocation
          new_dsl = dsl.sub(parts[1],parts[2])
          content.dsLocation = new_dsl
          gr.datastreams['DC'].update_values([:dc_identifier] => new_ids)
          gr.save
          puts "#{old_id} -> #{new_ids.inspect}"
        else
          puts "could not process '#{cmd}'"
        end
      end
    end   
    task :associate => :environment do
      path = ENV['list']
      raise "Can't process moves without a list of moves" unless path
      cmds = []
      open(path) do |f|
        f.each {|l| l.strip!; cmds << l}
      end
      ids = []
      cmds.each do |cmd|
        parts = cmd.split(' ')
        id = File.basename(parts[2])[0...-4]
        ids << id
      end
      objects = []
      dirname = '/Users/ba2213/Github/cul/ldpd-legacy-collections' 
      open(File.join(dirname,'object-manifest.txt')) do |f|
        f.each do |l|
          l.strip!
          objects << File.join(dirname,l)
        end
      end
      objects.each do |src|
        obj = nil
        if ids.length > 0
          open(src) {|s| obj = JSON.load(s)}
          obj['members'].each do |member|
            if ids.include? member['id']
              gr = GenericResource.search_repo(identifier: member['id']).first
              cagg = ContentAggregator.search_repo(identifier: obj['id']).first
              if gr and cagg
                gr.add_relationship(:cul_member_of, cagg.internal_uri)
                gr.save
                puts "found and updated #{member['id']}"
                ids.delete member['id']
              end
            end
          end
        end
      end
      if ids.length > 0
        ids.each {|id| puts "failed to update #{id}"}
      end
    end   
  end
end
