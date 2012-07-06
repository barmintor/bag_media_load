module Bag
  module Resource
    module Thumbnails
      # Create thumbnail requires that the characterization has already been run (so mime_type, width and height is available)
      # and that the object is already has a pid set
      def create_thumbnail
        return if self.content.content.nil?
        if ["application/pdf"].include? self.mime_type
          create_pdf_thumbnail
        elsif ["image/png","image/jpeg", "image/gif"].include? self.mime_type
          create_image_thumbnail
          # TODO: if we can figure out how to do video (ffmpeg?)
          #elsif ["video/mpeg", "video/mp4"].include? self.mime_type
        end
      end
    end
  end
end