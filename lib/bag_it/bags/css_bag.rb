module BagIt
  module Bags
    class CssBag < BagIt::Bags::DefaultBag
      def load
        manifest = @bag_info.manifest('md5')
        puts "Searching for \"#{@bag_info.external_id}\""
        bag_id = @bag_info.external_id
        bag_agg = ContentAggregator.find_by_identifier(bag_id)
        if bag_agg.blank?
          pid = next_pid
          puts "NEXT PID: #{pid}"
          bag_agg = ContentAggregator.new(:pid=>pid)
          bag_agg.dc.identifier = bag_id
          bag_agg.dc.title = @bag_info.external_desc
          bag_agg.dc.dc_type = 'Collection'
          bag_agg.label = @bag_info.external_desc
          bag_agg.descMetadata.content = 
            open(File.join(@bag_path,'data', bag_id, "#{bag_id}_mods.xml"))
          bag_agg.save
          @parent.add_member(bag_agg) unless @parent.nil?
        end

        recto_path = File.join(@bag_path,'data', bag_id, "#{bag_id}r.tif")
        recto_path = File.join(@bag_path,'data', bag_id, "#{bag_id}.tif") unless File.file? recto_path
        verso_path = File.join(@bag_path,'data', bag_id, "#{bag_id}v.tif")
        if File.file? recto_path
          recto = manifest.find_or_create_resource(recto_path)
          recto.set_title_and_label("#{bag_id} (recto)")
          recto.add_dc_identifier("#{bag_id}r")
          recto.derivatives!
          tech_md_path = recto_path + ".fits.xml"
          tech_md_sources = BagIt::Manifest.sources(tech_md_path)
          tech_md = recto.create_datastream(ActiveFedora::Datastream, "techMetadata",
                                           :controlGroup => 'M', :dsLabel => tech_md_sources[0])
          tech_md.content = open(tech_md_path)
          recto.add_datastream(tech_md)
          recto.save
          bag_agg.add_member(recto)
          recto.save
        end

        if File.file? verso_path
          verso = manifest.find_or_create_resource(verso_path)
          verso.set_title_and_label("#{bag_id} (verso)")
          verso.add_dc_identifier("#{bag_id}v")
          verso.derivatives!
          tech_md_path = verso_path + ".fits.xml"
          tech_md_sources = BagIt::Manifest.sources(tech_md_path)
          tech_md = verso.create_datastream(ActiveFedora::Datastream, "techMetadata",
                                           :controlGroup => 'M', :dsLabel => tech_md_sources[0])
          tech_md.content = open(tech_md_path)
          verso.add_datastream(tech_md)
          verso.save
          bag_agg.add_member(verso)
          verso.save
        end
        # create_datastream(ActiveFedora::Datastream, dsid, :controlGroup => 'M', :mimeType=>mimeType, :dsLabel=>ds_label, :versionable=>false)
        puts "INFO: Finished loading #{@bag_path}"
      end
    end
  end
end
