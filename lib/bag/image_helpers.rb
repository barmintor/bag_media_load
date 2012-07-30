require 'uri'
require 'open-uri'
require 'tempfile'
module Bag
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
          image_properties = Cul::Image::Properties.identify(blob)
        }
      else
        blob = Tempfile.new("blob")
        blob.write(ds.content)
        blob.close
        blob.open
        image_properties = Cul::Image::Properties.identify(blob)
        blob.close unless blob.closed?
      end
      image_prop_nodes = image_properties.nodeset
      image_prop_nodes.each { |node|
        if node["resource"]
          is_literal = false
          object = RDF::URI.new(node["resource"])
        else
          is_literal = true
          object = RDF::Literal(node.text)
        end
        predicate = RDF::URI("#{node.namespace.href}#{node.name}")
        obj.relationships(predicate).dup.each { |val|
          obj.remove_relationship(predicate,val)
        }
        obj.add_relationship(predicate,object, is_literal)
        obj.relationships_are_dirty=true
      }
    end
  end
end
