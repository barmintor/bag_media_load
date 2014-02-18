module BagIt
  module Resource
    # Create thumbnail requires that the characterization has already been run (so mime_type, width and height is available)
    # and that the object is already has a pid set
    def create_thumbnail(image, mime_type, temp_file)
      return if self.content.content.nil?
      if ["application/pdf"].include? mime_type
        nil # create_pdf_thumbnail
      elsif ["image/png","image/jpeg", "image/gif", "image/tif", "image/jp2"].include? mime_type
        create_scaled_image(image, 200, temp_file)
      else
        nil
      end
    end

    def create_scaled_image(image, scale, temp_file)
      image.thumbnail(scale) do |scaled|
        scaled.save(temp_file.path)
      end
    end
  end
end