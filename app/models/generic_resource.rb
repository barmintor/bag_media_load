require "active-fedora"
require "cul_image_props"
require "mime/types"
require "net/http"
require "uri"
require "open-uri"
require "tempfile"
require "bag_it"
class GenericResource < ::ActiveFedora::Base
  extend ActiveModel::Callbacks
  include ::ActiveFedora::Finders
  include ::ActiveFedora::DatastreamCollections
  include ::Hydra::ModelMethods
  include Cul::Scv::Hydra::Models::Common
  include Cul::Scv::Hydra::Models::ImageResource
  include Cul::Scv::Fedora::UrlHelperBehavior
  include BagIt::DcHelpers
  include BagIt::Resource
  include ::ActiveFedora::RelsInt

  has_and_belongs_to_many :containers, :property=>:cul_member_of, :class_name=>'ActiveFedora::Base'  

  IMAGE_EXT = {"image/bmp" => 'bmp', "image/gif" => 'gif', "image/jpeg" => 'jpg',
   "image/png" => 'png', "image/tiff" => 'tif', "image/x-windows-bmp" => 'bmp',
   "image/jp2" => 'jp2'}
  WIDTH = RDF::URI(ActiveFedora::Predicates.find_graph_predicate(:image_width))
  LENGTH = RDF::URI(ActiveFedora::Predicates.find_graph_predicate(:image_length))
  EXTENT = RDF::URI(ActiveFedora::Predicates.find_graph_predicate(:extent))
  FORMAT = RDF::URI(ActiveFedora::Predicates.find_graph_predicate(:format))
  FORMAT_OF = RDF::URI(ActiveFedora::Predicates.find_graph_predicate(:format_of))
  # valid EXIF Rotation values are 1,2,3,4,5,6,7,8
  # but 2,4,5,7 represent horizontal flipping that is undetectable ex post facto
  # without recourse to the photographed object, so treat as closest fit
  DEROTATION_OFFSET = {1 => 0, 2 => 0, 3 => 180, 4 => 180,  5=> 90, 6 => 90, 7=> 270, 8 => 270}
  
  #has_relationship "image_width", :cul_image_width
  #has_relationship "image_length", :cul_image_length
  #has_relationship "x_sampling", :x_sampling
  #has_relationship "y_sampling", :y_sampling
  #has_relationship "sampling_unit", :sampling_unit
  #has_relationship "extent", :extent
  
  has_datastream :name => "content", :type=>::ActiveFedora::Datastream, :versionable => true

  def hack_rels!
    # and now for super hacks
    content = self.rels_ext.content
    self.rels_ext.content = self.rels_ext.datastream_content
    self.rels_ext.model.relationships_are_not_dirty!
    Cul::Scv::Fedora.repository.api.modify_datastream(pid: self.pid, dsid: 'RELS-EXT', content: content, content_type: "application/rdf+xml")
    self.rels_ext.send :reset_profile_attributes
  end

  def container_uris_for(obj,obs=false)
    r = obj.relationships(:cul_member_of)
    if obs # clean up from failed runs previous
      r += obj.relationships(:cul_obsolete_from)
    end
    r
  end

  def assert_content_model
    super
    add_relationship(:has_model, RDF::URI('info:fedora/ldpd:GenericResource'))
    add_relationship(:rdf_type, RDF::URI(Cul::Scv::Hydra::Models::RESOURCE_TYPE.to_s))
  end

  def route_as
    "resource"
  end

  def index_type_label
    "FILE ASSET"
  end

  def to_solr(solr_doc = Hash.new, opts={})
    super
    unless solr_doc["extent_ssi"] || self.datastreams["content"].nil?
      solr_doc["extent_ssi"] = [self.datastreams["content"].size]
    end
    solr_doc
  end

  def set_title_and_label(new_title, opts={})
      if opts[:only_if_blank]
        if self.label.nil? || self.label.empty?
          self.label = new_title
          self.set_title( new_title )
        end
      else
        self.label = new_title
        set_title( new_title )
      end
    end

    # Set the title and label on the current object
    #
    # @param [String] new_title
    # @param [Hash] opts (optional) hash of configuration options
    def set_title(new_title, opts={})
      if has_desc? 
        desc_metadata_ds = self.datastreams["descMetadata"]
        if desc_metadata_ds.respond_to?(:title_values)
          desc_metadata_ds.title_values = new_title
        else
          desc_metadata_ds.title = new_title
        end
        if dc.respond_to?(:title_values)
          dc.title_values = new_title
        else
          dc.title = new_title
        end
      end
    end
    
    def image_blob(dsLocation)
      img = Magick::Image.ping(dsLocation)
      img = Array(img).first
      img
    end      
    
    def derivatives!(opts={:override=>false})
      ds = datastreams["content"]
      opts = {:upload_dir => '/var/tmp/bag_media_load'}.merge(opts)
      if ds and IMAGE_EXT.include? ds.mimeType
        dsLocation = (ds.dsLocation =~ /^file:\//) ? ds.dsLocation.sub(/^file:/,'') : ds.dsLocation
        begin
          content_ds_props = nil
          # generate content DS rels
          if rels_int.dsCreateDate.nil? or rels_int.dsCreateDate < ds.dsCreateDate or opts[:override] or long() == 0
            File.open(dsLocation,:encoding=>'BINARY') do |blob|
              content_ds_props = ds_rels(blob,ds)
              @width = @length = nil
            end
          end
          rels_int.serialize!
          self.save
          uri = URI.parse(derivative_url())
          Net::HTTP.new(uri.host, uri.port) {|http| http.head(uri.request_uri).code}
        rescue Exception => e
          Rails.logger.error "Cannot generate derivatives for #{self.pid} : #{e.message}\n    " + e.backtrace.join("\n    ")
        end
      end
    end

    def derivative_url(opts={})
      opts = {size:1, id: self.pid, type: 'scaled', format:'jpg'}.merge(opts)
      "#{IMG_CONFIG['base']}/#{opts[:id]}/#{opts[:type]}/#{opts[:size]}.#{opts[:format]}"
    end

    def ds_rels(blob, ds)
      image_properties = Cul::Image::Properties.identify(blob)
      if image_properties
        image_prop_nodes = image_properties.nodeset
        image_prop_nodes.each do |node|
          value = node["resource"] || node.text
          predicate = RDF::URI.new("#{node.namespace.href}#{node.name}")
          rels_int.clear_relationship(ds, predicate)
          rels_int.add_relationship(ds, predicate, value, node["resource"].blank?)
        end
      end
      image_properties
    ensure
      blob.close
    end
        
    def migrate!
      if datastreams["CONTENT"] and not relationships(:has_model).include? self.class.to_class_uri
        Rails.logger.info "#{self.pid} appears to be an old-style ldpd:Resource"
        migrate_content
        assert_content_model
        remove_cmodel("info:fedora/ldpd:Resource")
        migrate_membership
        #hack_rels!
      else
        Rails.logger.debug "No content migration necessary for #{self.pid}"
        migrate_content
        migrate_membership
        #hack_rels!
      end
      collapse_ids
      save
    end

    def migrate_membership
      container_uris_for(self).clone.each do |parent_uri|
        parent_pid = parent_uri.split('/')[-1]
        parent = ActiveFedora::Base.find(parent_pid, cast: true)
        if parent.relationships(:has_model).include? StaticImageAggregator.to_class_uri
          gp_uris = container_uris_for(parent, true)
          gp_uris.each { |gp_uri|
            self.add_relationship(:cul_member_of, RDF::URI(gp_uri.to_s))
            parent.add_relationship(:cul_obsolete_from, RDF::URI(gp_uri.to_s))
            parent.remove_relationship(:cul_member_of, RDF::URI(gp_uri.to_s))
            parent.save
          }
          self.remove_relationship(:cul_member_of, parent)
        else
          Rails.logger.info "didn't match SIA class" + parent.relationships(:has_model).inspect
        end
      end
    end
    
    def migrate_content
      old = datastreams["CONTENT"]
      nouv = datastreams["content"]
      if old and not nouv
        Rails.logger.info "datastreams/content@dsLocation = #{old.dsLocation}"
        dsLocation = old.dsLocation
        if old.controlGroup == 'M' or old.controlGroup == 'X'
          raise "WWW URL for DS content not yet implemented!" 
        end
        dsLabel = dsLocation.split('/')[-1]
        nouv = create_datastream(ActiveFedora::Datastream, 'content', :controlGroup=>old.controlGroup, :dsLocation=>dsLocation, :mimeType=>old.mimeType, :dsLabel=>dsLabel)
        add_datastream(nouv)
        dsLocation = (dsLocation =~ /^file:\//) ? dsLocation.sub(/^file:/,'') : dsLocation
        ds_rels(File.open(dsLocation),nouv)
      end
      clear_relationship(:cul_image_length)
      clear_relationship(:cul_image_width)
      clear_relationship(:format)
      clear_relationship(:extent)
      clear_relationship(:x_sampling)
      clear_relationship(:y_sampling)
      clear_relationship(:sampling_unit)
    end
    
    def remove_cmodel(cmodel)
      self.remove_relationship(:has_model, RDF::URI(cmodel))
    end
    
    def collapse_ids
      dc = datastreams["DC"]
      ids = dc.term_values(:dc_identifier)
      new_ids = ids.uniq
      return if new_ids.sort.eql? ids.sort
      self.set_dc_identifier(self.pid)
      new_ids.each {|idval| self.add_dc_identifier(idval) if idval != self.pid}
      dc.content_will_change!
    end

    def tempfile(name_parts, temp_root='/var/tmp/bag_media_load')
      Tempfile.new(name_parts, temp_root)
    end

    private
    def long
      @long_side ||= max(width(), length())
    end

    def width
      @width ||= begin
        ds = datastreams["content"]
        width = 0
        unless rels_int.relationships(ds,:image_width).blank?
          width = rels_int.relationships(ds,:image_width).first.object.to_s.to_i
        end
        width = relationships(:cul_image_width).first.to_s.to_i if width == 0
        width
      end
    end
    def length
      @length ||= begin
        ds = datastreams["content"]
        length = 0
        unless rels_int.relationships(ds,:image_length).blank?
          length = rels_int.relationships(ds,:image_length).first.object.to_s.to_i
        end
        length = relationships(:cul_image_length).first.to_s.to_i if length == 0
        length
      end
    end
end
