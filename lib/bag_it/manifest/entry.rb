module BagIt
  class Manifest
    class Entry
      attr_accessor :path, :mime, :derivatives, :title
      def initialize(opts)
        @path = opts[:path]
        @mime = opts[:mime] || Entry.mime_for_name(path)
        @local_id = opts[:local_id]
        @original = true
        @derivatives = []
      end
      def original?
        @original
      end
      def local_id
        original? ? 'content' : @local_id
      end
      def original_path
        ix = path.index(/\/data\//)
        ix += 6 if ix
        if !ix && path =~ /^data/
          ix = 5
        end
        ix ||= 0 
        path[ix..-1]
      end
      def title
        @title ||= default_title
      end
      def image?
        dc_type.eql? 'Image'
      end
      def text?
        ['PageDescription','StructuredText','UnstructuredText'].include? dc_type
      end
      def video?
        dc_type.eql? 'Video'
      end
      def audio?
        dc_type.eql? 'Audio'
      end
      def document?
        text? || (['Spreadsheet','Presentation'].include? dc_type)
      end
      def default_title
        if image?
          dt = 'Image'
        elsif document?
          dt = text? ? 'Text Document' : "#{dc_type} Document"
        elsif video?
          dt = 'Recording'
        elsif audio?
          dt = 'Recording'
        else
          dt = 'File Artifact'
        end
        return original? ? "Preservation #{dt}" : dt
      end
      def dc_type
        @dc_type ||= begin
          if pronom_format
            pf = PronomFormat.find(pronom_format)
            dt = pf.pcdm_type
          else
            if IMAGE_TYPES.include? mime or mime.start_with? 'image'
              dt = 'Image'
            elsif DOC_TYPES.include? mime
              dt = 'PageDescription'
            elsif PRESENTATION_TYPES.include? mime
              dt = 'Presentation'
            elsif SPREADSHEET_TYPES.include? mime
              dt = 'Spreadsheet'
            elsif VIDEO_TYPES.include? mime or mime.start_with? 'video'
              dt = 'Video'
            elsif AUDIO_TYPES.include? mime or mime.start_with? 'audio'
              dt = 'Audio'
            elsif XML_TYPES.include? mime or mime() =~ /xml$/
              dt = 'StructuredText'
            elsif TEXT_TYPES.include? mime or mime.start_with? 'text'
              dt = 'UnstructuredText'
            else
              dt = 'Unknown'
            end
          end
          dt
        end
      end
      def mime
        @mime ||= Entry.mime_for_name(path)
      end
      def pronom_format
        @pronom_format
      end
      def pronom_format=(puid)
        @pronom_format = puid
      end
      def self.mime_for_name(filename)
        if filename.nil?
          mt = nil
        else
          ext = File.extname(filename).downcase
          mt = MIME::Types.type_for(ext)
        end
        if mt.is_a? Array
          mt = mt.first
        end
        unless mt.nil?
          return mt.content_type
        else
          return OCTETSTREAM
        end
      end
    end    
  end
end