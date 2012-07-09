require "active-fedora"
require "cul_image_props"
require "mime/types"
require "uri"
require "uri-open"
class GenericResource < ::ActiveFedora::Base
  extend ActiveModel::Callbacks
  include ::ActiveFedora::Finders
  include ::ActiveFedora::DatastreamCollections
  include ::ActiveFedora::Relationships
  include ::Hydra::ModelMethods
  include Cul::Scv::Hydra::ActiveFedora::Model::Common
  alias :file_objects :resources
  
  IMAGE_EXT = {"image/bmp" => 'bmp', "image/gif" => 'gif', "imag/jpeg" => 'jpg', "image/png" => 'png', "image/tiff" => 'tif', "image/x-windows-bmp" => 'bmp'}
  WIDTH = RDF::URI(ActiveFedora::Predicates.find_graph_predicate(:image_width))
  LENGTH = RDF::URI(ActiveFedora::Predicates.find_graph_predicate(:image_length))
  
  has_relationship "image_width", :image_width
  has_relationship "image_length", :image_length
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
    
    def derivatives!(opts={:override=>false})
      ds = datastreams["content"]
      if ds and IMAGE_EXT.include? ds.mimeType
        width = relationships(WIDTH).first.to_s.to_i
        length = relationships(LENGTH).first.to_s.to_i
        long = (width > length) ? width : length
        dsLocation = (ds.dsLocation =~ /^file:\//) ? ds.dsLocation.replace('file:','') : ds.dsLocation
        img = Magick::ImageList.new
        img.from_blob(open(dsLocation))
        unless datastreams["thumbnail"] and not opts[:override]
          if long > 200
            factor = 200 / long
            dsid = "thumbnail"
            derivative!(img, factor, dsid)
          end
        end
        unless datastreams["web850"] and not opts[:override]
          if long > 850
            factor = 850 / long
            dsid = "web850"
            derivative!(img, factor, dsid)
          end
        end
        unless datastreams["web1500"] and not opts[:override]
          if long > 1500
            factor = 1500 / long
            dsid = "web1500"
            derivative!(img, factor, dsid)
          end
        end
        unless datastreams["jp2"] and not opts[:override]
          zoomable!(img, "jp2")
        end
      end
    end
    
    def derivative!(image, factor, dsid, mimeType = 'image/png')
      ext = EXT[mimeType]
      ds_label = "#{dsid}.#{ext}"
      img =  image.adaptive_resize(factor)
      img_ds = datastreams[dsid]
      if img_ds
        img_ds.label = ds_label unless img_ds.label == ds_label
        img_ds.mimeType = mimeType unless img_ds.mimeType == mimeType
        img_ds.content = img.to_blob { self.format = ext}
      else
        img_ds = create_datastream(:dsid => dsid, :controlGroup => 'M', :mimeType=>mimeType, :label=>ds_label)
        img_ds.content = img.to_blob { self.format = ext}
        add_datastream(img_ds)
      end
      self.save
    end
    
    def zoomable!(image, dsid)
      ext = 'jp2'
      ds_label = "#{dsid}.#{ext}"
      self.save
    end
    
    def migrate!
      if datastreams["CONTENT"] and not relationships(:has_model).include? self.class.to_class_uri
        puts "This object appears to be an old-style ldpd:Resource"
        migrate_content
        assert_content_model
        remove_content_model("info:fedora/ldpd:Resource")
        save
      else
        puts "No migration necessary"
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
        nouv = create_datastream(:dsid=>'content', :controlGroup=>old.controlGroup, :dsLocation=>dsLocation, :mimeType=>old.mimeType, :label=>old.label)
        add_datastream(nouv)
      end
    end
    
    def remove_cmodel(cmodel)
      object = RDF::URI.new(cmodel)
      subject = RDF::URI.new(internal_uri)
      predicate = ActiveFedora::Predicates.find_graph_predicate(:has_model)
      relationships.delete RDF::Statement.new(subject, predicate, object)
    end
    
end