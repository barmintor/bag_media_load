module BagMediaLoad::MigrationHelpers
  IMAGE_EXT = {"image/bmp" => 'bmp', "image/gif" => 'gif', "image/jpeg" => 'jpg',
   "image/png" => 'png', "image/tiff" => 'tif', "image/x-windows-bmp" => 'bmp',
   "image/jp2" => 'jp2'}
  extend ActiveSupport::Concern
  def derivatives!(opts={:override=>false},derivative_entries=[])
    ds = datastreams["content"]
    opts = {:upload_dir => '/var/tmp/bag_media_load'}.merge(opts)
    if ds and IMAGE_EXT.include? ds.mimeType
      dsLocation = ds_uri_to_path(ds.dsLocation)
      begin
        content_ds_props = nil
        # generate content DS rels
        if rels_int.dsCreateDate.nil? or rels_int.dsCreateDate < ds.dsCreateDate or opts[:override] or long() == 0
          content_ds_props = image_rels(dsLocation,ds)
          @width = @length = nil
        end
        rels_int.serialize!
        self.save
        uri = URI.parse(derivative_url())
        Net::HTTP.new(uri.host, uri.port) {|http| http.head(uri.request_uri).code}
      rescue Exception => e
        Rails.logger.error "Cannot generate derivatives for #{self.pid} : #{e.message}\n    " + e.backtrace.join("\n    ")
      end
    end
    derivative_entries.each do |entry|
      dsid = entry.local_id
      label = File.basename(entry.path)
      mimeType = entry.mime
      mimeType ||= mime_for_name(entry.path)
      ds = datastreams[dsid]
      if ds
        ds.mimeType = mimeType unless ds.mimeType == mimeType || mimeType.nil?
        ds.dsLabel = label unless ds.dsLabel == label
      else
        ds_parms = {
          controlGroup: 'E',
          dsLabel: label,
          dsLocation: path_to_ds_uri(entry.path),
          mimeType: mimeType,
          versionable: false
        }
        ds = create_datastream(ActiveFedora::Datastream,dsid,ds_parms)
        add_datastream(ds)
      end
      if rels_int.relationships(ds, :format_of).empty?
        rels_int.add_relationship(ds, :format_of, datastreams["content"])
        rels_int.serialize!
      end
    end
    self.save
  end

  def migrate!
    if datastreams["CONTENT"] and not relationships(:has_model).include? self.class.to_class_uri
      Rails.logger.info "#{self.pid} appears to be an old-style ldpd:Resource"
      migrate_content
      assert_content_model
      remove_cmodel("info:fedora/ldpd:Resource")
      migrate_membership
    else
      Rails.logger.debug "No content migration necessary for #{self.pid}"
      migrate_content
      migrate_membership
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
      image_rels(dsLocation,nouv)
    end
    clear_obsolete_rels()
  end
  def clear_obsolete_rels
    clear_relationship(:cul_image_length)
    clear_relationship(:cul_image_width)
    clear_relationship(:format)
    clear_relationship(:extent)
    clear_relationship(:x_sampling)
    clear_relationship(:y_sampling)
    clear_relationship(:sampling_unit)
  end
end