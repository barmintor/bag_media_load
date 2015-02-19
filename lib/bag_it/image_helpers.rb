require 'uri'
require 'open-uri'
require 'tempfile'
module BagIt
  module ImageHelpers
    def setImageProperties(obj)
      ds = obj.datastreams['content']
      image_properties = nil
      if ds.controlGroup == 'E' && ds.dsLocation =~ /file:/
        path = ds.dsLocation.sub(/file:/,'')
      else
        blob = Tempfile.new("blob")
        blob.write(ds.content)
        blob.close
        blob.unlink
        path = blob.path
      end
      obj.image_rels(path,ds)
    end
  end
end
