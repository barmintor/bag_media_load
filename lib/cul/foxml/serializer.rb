require 'stringio'
require 'base64'
module Cul
  module Foxml
    class Serializer
      SERIALIZE_DATASTREAM = proc {|ds, io, block| serialize_datastream(ds, io, &block) }
      SERIALIZE_DATASTREAM_VERSION = proc {|ds, io, block| serialize_datastream_version(ds, io, &block) }
      SERIALIZE_DATASTREAM_CONTENT = proc {|ds, io, block| serialize_datastream_content(ds, io, &block) }
      def self.serialize_object(af_object, io = StringIO.new, &block)
        block = SERIALIZE_DATASTREAM unless block_given?
        if af_object.object_relations[:has_model].blank?
          af_object.assert_content_model
        end
        # write root element
        io << "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
        io << '<foxml:digitalObject VERSION="1.1" '
        io << "PID=\"#{af_object.pid}\""
        io << "\nxmlns:foxml=\"info:fedora/fedora-system:def/foxml#\""
        io << "\nxmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\""
        io << "\nxsi:schemaLocation=\"info:fedora/fedora-system:def/foxml# http://www.fedora.info/definitions/1/0/foxml1-1.xsd\">\n"
        serialize_object_properties(af_object, io)
        af_object.datastreams.keys.sort.each do |dsid|
          ds = af_object.datastreams[dsid]
          next unless ds.changed? || ds.has_content?
          block.yield ds, io
        end
        io << "</foxml:digitalObject>"
        io
      end

      def self.serialize_object_properties(af_object, io = StringIO.new)
        # write object properties 
        io << "<foxml:objectProperties>\n"
        case af_object.state
        when 'D'
          state = 'Deleted'
        when 'I'
          state = 'Inactive'
        else
          state = 'Active'
        end
        io << "<foxml:property NAME=\"info:fedora/fedora-system:def/model#state\" VALUE=\"#{state}\"/>\n"
        io << "<foxml:property NAME=\"info:fedora/fedora-system:def/model#label\" VALUE=\"#{af_object.label}\"/>\n"
        io << "</foxml:objectProperties>\n"
        io
      end

      def self.serialize_datastream(af_datastream, io = StringIO.new, &block)
        io << "<foxml:datastream ID=\"#{af_datastream.dsid}\" STATE=\"#{af_datastream.state}\" CONTROL_GROUP=\"#{af_datastream.controlGroup}\" VERSIONABLE=\"#{af_datastream.versionable}\">\n"
        block = SERIALIZE_DATASTREAM_VERSION unless block_given?
        block.yield af_datastream, io
        io << "</foxml:datastream>\n"
        io
      end

      def self.serialize_datastream_version(af_datastream, io = StringIO.new, &block)
        io << "<foxml:datastreamVersion ID=\"#{af_datastream.dsid}.0\""
        io << " LABEL=\"#{af_datastream.dsLabel}\" MIMETYPE=\"#{af_datastream.mimeType}\""
        io << " FORMAT_URI=\"#{af_datastream.formatURI}\"" if af_datastream.formatURI.present?
        io << ">\n"
        block = SERIALIZE_DATASTREAM_CONTENT unless block_given?
        block.yield af_datastream, io
        io << "</foxml:datastreamVersion>\n"
        io
      end

      def self.serialize_datastream_content(af_datastream, io = StringIO.new, &block)
        if af_datastream.dsLocation.present? && af_datastream.controlGroup == 'E'
          io << "<foxml:contentLocation TYPE=\"URL\" REF=\"#{af_datastream.dsLocation}\"/>\n"
        elsif af_datastream.controlGroup == 'X'
          serialize_inline_datastream_content(af_datastream, io, &block)
        else
          serialize_binary_datastream_content(af_datastream, io, &block)
        end
        io
      end

      def self.serialize_binary_datastream_content(af_datastream, io = StringIO.new, &block)
        io << "<foxml:binaryContent>"
        if af_datastream.changed_attributes.has_key?('content') && af_datastream.content.present?
          io << Base64.encode64(strip_instruction(af_datastream.content))
        elsif af_datastream.changed_attributes.has_key? 'ng_xml'
          io << Base64.encode64(strip_instruction(af_datastream.to_xml))
        elsif af_datastream.is_a? ActiveFedora::RelsExtDatastream 
          io << Base64.encode64(strip_instruction(af_datastream.to_rels_ext))
        elsif af_datastream.is_a? ActiveFedora::RelsInt::Datastream 
          io << Base64.encode64(strip_instruction(af_datastream.to_rels_int))
        end
        io << "</foxml:binaryContent>\n"
        io
      end

      def self.serialize_inline_datastream_content(af_datastream, io = StringIO.new, &block)
        io << "<foxml:xmlContent>"
        if af_datastream.changed_attributes.has_key?('content') && af_datastream.content.present?
          io << strip_instruction(af_datastream.content)
        elsif af_datastream.changed_attributes.has_key? 'ng_xml'
          io << strip_instruction(af_datastream.to_xml)
        elsif af_datastream.is_a? ActiveFedora::RelsExtDatastream 
          io << strip_instruction(af_datastream.to_rels_ext)
        elsif af_datastream.is_a? ActiveFedora::RelsInt::Datastream 
          io << strip_instruction(af_datastream.to_rels_int)
        end
        io << "</foxml:xmlContent>\n"
        io
      end

      def self.strip_instruction(xml='')
        xml.sub(/^<\?.+\?>/,'')
      end
    end
  end
end