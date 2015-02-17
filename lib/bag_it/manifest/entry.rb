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
        IMAGE_TYPES.include? mime or mime.start_with? 'image'
      end
      def text?
        TEXT_TYPES.include? mimetype or mimetype.start_with? 'text'
      end
      def video?
        VIDEO_TYPES.include? mimetype or mimetype.start_with? 'video'
      end
      def audio?
        AUDIO_TYPES.include? mimetype or mimetype.start_with? 'audio'
      end
      def default_title
        if image?
          dt = 'Image'
        elsif text?
          dt = 'File Artifact'
        elsif video?
          dt = 'Recording'
        elsif audio?
          dt = 'Recording'
        else
          dt = 'File Artifact'
        end
        return original? ? "Preservation: #{dt}" : dt
      end
      def dc_type
        if image?
          dt = 'StillImage'
        elsif text?
          dt = 'Text'
        elsif video?
          dt = 'MovingImage'
        elsif audio?
          dt = 'Sound'
        else
          dt = 'Software'
        end
        dt
      end
      def mime
        @mime ||= Entry.mime_for_name(path)
      end
      def self.mime_for_name(filename)
        ext = File.extname(filename).downcase
        mt = MIME::Types.type_for(ext)
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