require "rake"
require "active-fedora"
require "cul_scv_hydra"
require "nokogiri"
require 'cul_repo_cache'
require "bag_it"
require 'thread/pool'
include Cul::Repo::Constants
module KorInd
  PROJECT_URI = 'http://www.columbia.edu/cgi-bin/cul/resolve?clio7688161'
  def load_ko_objects(dir)
    objects = []
    open(File.join(dir, 'objects.json')) do |blob|
      objects = JSON.load(blob)
    end
    objects
  end
end
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


namespace :util do
  namespace :korind do
    desc 'create the project bagg'
    task :setup => :environment do
      include KorInd
      all_collections = BagAggregator.search_repo(identifier: LDPD_PROJECTS_ID).first
      raise "Could not find LDPD collections aggregator at #{LDPD_PROJECTS_ID}" unless all_collections
      korind = BagAggregator.search_repo(identifier: KorInd::PROJECT_URI).first
      unless korind
        ids = ['ldpd.koreanoutbreak',KorInd::PROJECT_URI]
        title = "Content for the Korean Independence Outbreak Movement"
        korind = BagAggregator.new(pid: next_pid())
        korind.label = title
        korind.datastreams["DC"].update_values({[:dc_title] => title})
        korind.datastreams["DC"].update_values({[:dc_identifier] => ids})
        korind.datastreams["DC"].update_values({[:dc_type] => 'Collection'})
        korind.add_relationship(:cul_member_of, all_collections.internal_uri)
        korind.save
      end
      @project = korind.internal_uri
    end
    task :load_mods => :setup do
      raise "No project bag aggregator!" unless @project
      dir = ENV['mods_dir']
      raise "MODS data root directory param is required 'mods_dir'" unless dir
      objects = load_ko_objects(dir)
      objects.each do |object|
      	cagg = nil
      	mods_path = File.join(dir,object['mods'])
      	ng_xml = open(mods_path) {|f| Nokogiri::XML(f) }
      	title = ng_xml.css("mods titleInfo title").first.text
      	if object['pid']
      		cagg = ContentAggregator.find(object['pid'])
      	else
      		cagg = ContentAggregator.search_repo(identifier: object['id']).first
      		unless cagg
      			cagg = ContentAggregator.new(pid: next_pid())
      			dc = cagg.datastreams['DC']
		        dc.update_values({[:dc_title] => title})
		        dc.update_values({[:dc_identifier] => object['id']})
		        dc.update_values({[:dc_type] => 'InteractiveResource'})
		        cagg.add_relationship(:cul_member_of, @project)
            dc.content_will_change!
            open(mods_path) {|f| cagg.datastreams['descMetadata'].content = f.read }
            cagg.save
          end
        end
        ds = cagg.datastreams['structMetadata']
        if ds.new?
          ds.label = 'Sequence'
          ds.type = 'logical'
          order = Proc.new {|c| c['id'].split('.')[-1].to_i}
          object['children'].sort! {|a,b| order.call(a) <=> order.call(b)}
          object['children'].each_with_index do |child, ix|
            b1 = (1 + ix).to_s
            ds.create_div_node(nil, {:order=>b1, :label=>"Item #{b1}", :contentids=>child['id']})
          end
          cagg.save
        end
        object['children'].each do |child|
          mods_path = File.join(dir,child['mods'])
          gr = GenericResource.find(child['pid'])
          if gr
            dc = gr.datastreams['DC']
            gr.add_dc_identifier(child['id'])
            dc.content_will_change!
            gr.add_relationship(:cul_member_of, cagg.internal_uri)
            gr.save
          end
        end
      end
    end
    task :structure => :setup do
      raise "No project bag aggregator!" unless @project
      dir = ENV['mods_dir']
      raise "MODS data root directory param is required 'mods_dir'" unless dir
      objects = load_ko_objects(dir)
      objects.each do |object|
        cagg = nil
        mods_path = File.join(dir,object['mods'])
        ng_xml = open(mods_path) {|f| Nokogiri::XML(f) }
        title = ng_xml.css("mods titleInfo title").first.text
        if object['pid']
          cagg = ContentAggregator.find(object['pid'])
        else
          cagg = ContentAggregator.search_repo(identifier: object['id']).first
          unless cagg
            cagg = ContentAggregator.new(pid: next_pid())
            dc = cagg.datastreams['DC']
            dc.update_values({[:dc_title] => title})
            dc.update_values({[:dc_identifier] => object['id']})
            dc.update_values({[:dc_type] => 'InteractiveResource'})
            cagg.add_relationship(:cul_member_of, @project)
            dc.content_will_change!
            open(mods_path) {|f| cagg.datastreams['descMetadata'].content = f.read }
            cagg.save
          end
        end
        ds = cagg.datastreams['structMetadata']
        ds.content = ds.class.xml_template
        ds.content_will_change!
        ds.label = 'Sequence'
        ds.type = 'logical'
        order = Proc.new {|c| c['id'].split('.')[-1].to_i}
        object['children'].sort! {|a,b| order.call(a) <=> order.call(b)}
        object['children'].each_with_index do |child, ix|
          b1 = (1 + ix).to_s
          ds.create_div_node(nil, {:order=>b1, :label=>"Item #{b1}", :contentids=>child['id']})
        end
        cagg.save
      end
    end
    task :repair => :setup do
      raise "No project bag aggregator!" unless @project
      dir = ENV['mods_dir']
      raise "MODS data root directory param is required 'mods_dir'" unless dir
      objects = load_ko_objects(dir)
      objects.each do |object|
        if object['pid']
          cagg = ContentAggregator.find(object['pid'])
        else
          cagg = ContentAggregator.search_repo(identifier: object['id']).first
        end
        object['children'].each do |child|
          mods_path = File.join(dir,child['mods'])
          gr = GenericResource.find(child['pid'])
          if gr
            dc = gr.datastreams['DC']
            src = dc.term_values(:dc_source).first
            if src.start_with? "/ifs/cul/ldpd/fstore/archive/preservation/korean_ind/data"
              _id = src.sub("/ifs/cul/ldpd/fstore/archive/preservation/korean_ind",
                            "apt://columbia.edu/burke.korean_ind")
              gr.add_dc_identifier(_id)
            end
            if cagg
              gr.add_relationship(:cul_member_of, cagg.internal_uri)
            end
            gr.save    
          end
        end
      end
    end
  end
end
