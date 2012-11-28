require "active-fedora"
require "cul_image_props"
require "mime/types"
require "uri"
require "open-uri"
require "tempfile"
require "bag"
require "image_science"
class GenericResource < ::ActiveFedora::Base
  extend ActiveModel::Callbacks
  include ::ActiveFedora::Finders
  include ::ActiveFedora::DatastreamCollections
  include ::ActiveFedora::Relationships
  include ::Hydra::ModelMethods
  include Cul::Scv::Hydra::ActiveFedora::Model::Common
  include Bag::DcHelpers
  include ::ActiveFedora::RelsInt
  alias :file_objects :resources
  
  IMAGE_EXT = {"image/bmp" => 'bmp', "image/gif" => 'gif', "imag/jpeg" => 'jpg', "image/png" => 'png', "image/tiff" => 'tif', "image/x-windows-bmp" => 'bmp'}
  WIDTH = RDF::URI(ActiveFedora::Predicates.find_graph_predicate(:image_width))
  LENGTH = RDF::URI(ActiveFedora::Predicates.find_graph_predicate(:image_length))
  
  has_relationship "image_width", :cul_image_width
  has_relationship "image_length", :cul_image_length
  has_relationship "x_sampling", :x_sampling
  has_relationship "y_sampling", :y_sampling
  has_relationship "sampling_unit", :sampling_unit
  has_relationship "extent", :extent
  
  has_datastream :name => "content", :type=>::ActiveFedora::Datastream, :versionable => true
  
  def assert_content_model
    super
    add_relationship(:rdf_type, Cul::Scv::Hydra::ActiveFedora::RESOURCE_TYPE.to_s)
  end

  def route_as
    "resource"
  end

  def index_type_label
    "FILE RESOURCE"
  end

  def to_solr(solr_doc = Hash.new, opts={})
    super
    unless solr_doc["extent_s"] || self.datastreams["content"].nil?
      solr_doc["extent_s"] = [self.datastreams["content"].size]
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
      img = img.first if img.is_a? Array
      img
    end      
    
    def derivatives!(opts={:override=>false})
      ds = datastreams["content"]
      if ds and IMAGE_EXT.include? ds.mimeType
        unless rels_int.relationships(ds,:image_width).blank?
          width = rels_int.relationships(ds,:image_width).first.object.to_s.to_i
        end
        unless rels_int.relationships(ds,:image_length).blank?
          length = rels_int.relationships(ds,:image_length).first.object.to_s.to_i
        end
        width ||= relationships(:cul_image_width).first.to_s.to_i
        length ||= relationships(:cul_image_length).first.to_s.to_i
        long = (width > length) ? width : length
        dsLocation = (ds.dsLocation =~ /^file:\//) ? ds.dsLocation.sub(/^file:/,'') : ds.dsLocation
        begin
          res = {}
          if datastreams["thumbnail"].nil? or opts[:override]
            if long > 200
              res["thumbnail"] = [200, Tempfile.new(["thumbnail",'.png'])]
              rels_int.clear_relationship(ds, :foaf_thumbnail)
              rels_int.add_relationship(ds,:foaf_thumbnail, internal_uri + "/thumbnail")
            end
          end
          if datastreams["web850"].nil? or opts[:override]
            if long > 850
              res["web850"] = [850, Tempfile.new(["web850",'.png'])]
            end
          end
          if datastreams["web1500"].nil? or opts[:override]
            if long > 1500
              res["web1500"] = [1500, Tempfile.new(["web1500",'.png'])]
            end
          end
          if datastreams["jp2"].nil? or opts[:override]
            #zoomable!(img, "jp2")
          end
          unless res.empty?
            ImageScience.with_image(dsLocation) do |img|
              res.each do |k,v|
                img.thumbnail(v[0]) do |scaled|
                  scaled.save(v[1].path)
                end
              end
            end
            res.each do |k,v|
              derivative!(v[1],k)
              v[1].unlink
            end
            puts "INFO Generated derivatives for #{self.pid}"
          else
            puts "INFO No required derivatives for #{self.pid}"
          end
          # generate content DS rels
          ds_rels(File.open(dsLocation),ds)
          self.save
        rescue Exception => e
          puts "ERROR Cannot generate derivatives for #{self.pid} : #{e.message}"
          puts e.backtrace
        end
      end
    end
    
    def derivative!(image, dsid, mimeType = 'image/png')
      ext = IMAGE_EXT[mimeType]
      ds_label = "#{dsid}.#{ext}"
      img_ds = datastreams[dsid]
      if img_ds
        img_ds.dsLabel = ds_label unless img_ds.dsLabel == ds_label
        img_ds.mimeType = mimeType unless img_ds.mimeType == mimeType
      else
        img_ds = create_datastream(ActiveFedora::Datastream, dsid, :controlGroup => 'M', :mimeType=>mimeType, :dsLabel=>ds_label, :versionable=>false)
      end
      img_content = File.open(image.path,:encoding=>'BINARY')
      # How can we get to the PUT without reading the file into memory?
      img_ds.content = img_content
      add_datastream(img_ds)
      puts "INFO #{dsid}.content.length = #{img_content.stat.size}"
      ds_rels(File.open(image.path,:encoding=>'BINARY'),img_ds)
      derivatives = rels_int.relationships(img_ds,:format_of)
      unless derivatives.inject(false) {|memo, rel| memo || rel.object == "#{internal_uri}/content"}
        rels_int.add_relationship(img_ds, :format_of,datastreams['content'])
      end
      self.save
    end
    
    def ds_rels(blob, ds)
      image_properties = Cul::Image::Properties.identify(blob)
      if image_properties
        image_prop_nodes = image_properties.nodeset
        image_prop_nodes.each do |node|
          value = node["resource"] || node.text
          predicate = "#{node.namespace.href}#{node.name}"
          rels_int.clear_relationship(ds, predicate)
          rels_int.add_relationship(ds, predicate, value, node["resource"].blank?)
        end
      end
    ensure
      blob.close
    end
    
    def zoomable!(image, dsid)
      ext = 'jp2'
      ds_label = "#{dsid}.#{ext}"
      self.save
    end
    
    def migrate!
      if datastreams["CONTENT"] and not relationships(:has_model).include? self.class.to_class_uri
        puts "INFO: #{self.pid} appears to be an old-style ldpd:Resource"
        migrate_content
        assert_content_model
        remove_cmodel("info:fedora/ldpd:Resource")
        migrate_membership
      else
        puts "INFO: No content migration necessary for #{self.pid}"
      end
      collapse_ids
      save
    end

    def migrate_membership
      relationships(:cul_member_of).clone.each do |parent_uri|
        parent_pid = parent_uri.split('/')[-1]
        parent = ActiveFedora::Base.find(parent_pid)
        if parent.relationships(:has_model).include?("info:fedora/ldpd:StaticImageAggregator")
          gp_uris = parent.relationships(:cul_member_of)
          gp_uris.each {|gp_uri| self.add_relationship(:cul_member_of, gp_uri)}
          remove_relationship(:cul_member_of, parent_uri)
        end
      end
    end
    
    def migrate_content
      old = datastreams["CONTENT"]
      nouv = datastreams["content"]
      if old and not nouv
        dsLocation = old.dsLocation
        if old.controlGroup == 'M' or old.controlGroup == 'X'
          raise "WWW URL for DS content not yet implemented!" 
        end
        nouv = create_datastream(ActiveFedora::Datastream, 'content', :controlGroup=>old.controlGroup, :dsLocation=>dsLocation, :mimeType=>old.mimeType, :dsLabel=>old.dsLabel)
        add_datastream(nouv)
        dsLocation = (dsLocation =~ /^file:\//) ? dsLocation.sub(/^file:/,'') : dsLocation
        ds_rels(File.open(dsLocation),nouv)
        rels_ext.clear_relationship(:cul_image_length)
        rels_ext.clear_relationship(:cul_image_width)
        rels_ext.clear_relationship(:format)
        rels_ext.clear_relationship(:extent)
      end
    end
    
    def remove_cmodel(cmodel)
      object_relations.delete(:has_model, cmodel)
      relationships_are_dirty=true
    end
    
    def collapse_ids
      ids = dc.term_values(:identifier)
      new_ids = ids.uniq
      return if new_ids.sort.eql? ids.sort
      if dc.respond_to?(:identifier_values)
        dc.identifier_values = ids.uniq
      else
        dc.identifier = ids.uniq
      end
      self.dc.dirty = true
    end
    
end
