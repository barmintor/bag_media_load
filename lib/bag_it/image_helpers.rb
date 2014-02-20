require 'uri'
require 'open-uri'
require 'tempfile'
module BagIt
  module ImageHelpers
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

end
