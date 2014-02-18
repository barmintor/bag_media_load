require 'uri'
require 'open-uri'
require 'tempfile'
module BagIt
  module ImageHelpers
    include Math
    def setImageProperties(obj)
      ds = obj.datastreams['content']
      image_properties = nil
      if ds.controlGroup == 'E'
        # get blob
        uri = URI.parse(ds.dsLocation)
        if uri.is_a? URI::Generic
          uri = ds.dsLocation.sub(/file:/,'')
        end
        open(uri) { |blob|
          obj.ds_rels(blob,ds)
        }
      else
        blob = Tempfile.new("blob")
        blob.write(ds.content)
        blob.close
        blob.open
        obj.ds_rels(blob,ds)
        blob.close unless blob.closed?
      end
    end

    # resolution levels for a given maximum pixel length
    # to be represented as 96px tiles
    # could be represented more compactly, but we are preserving
    # some questionable rounding from djatoka/openlayers
    def levels_for(max_pixel_length)
      return 0 if max_pixel_length < 192
      max_tiles = (max_pixel_length.to_f / 96)
      log2(max_tiles).floor
    end
  end
end
