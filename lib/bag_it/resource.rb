require 'cul_image_props'
require 'tempfile'
module BagIt
  module Resource

    include Math

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
      temp_file.close(false)
      image.thumbnail(scale) do |scaled|
        scaled.save(temp_file.path)
      end
      File.chmod(0644, temp_file.path)
    end

    def max(a, b)
      return (b > a) ? b : a
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

    def to_absolute_path(src_path)
      Pathname.new(src_path).realpath.to_path
    end

    def index_type_label
      "FILE ASSET"
    end
  end
end
