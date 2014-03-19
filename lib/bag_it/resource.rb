require 'cul_image_props'
require 'tempfile'
require 'mini_magick'
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
      File.chmod(644, temp_file.path)
    end

    def convert_to_jp2(src_path, temp_root=nil)
      src_path = to_absolute_path(src_path)
      rels = {}
      File.open(src_path) do |blob|
        rels = Cul::Image::Properties.identify(blob)
      end
      max = nil
      result = nil
      unless rels['http://www.w3.org/2003/12/exif/ns#imageLength'].nil?
        length = rels['http://www.w3.org/2003/12/exif/ns#imageLength'].to_i
        width = rels['http://www.w3.org/2003/12/exif/ns#imageWidth'].to_i
        levels = levels_for(max(length, width))

        File.open(src_path) do |blob|
          image = MiniMagick::Image.read(blob)
          # for grayscale:
          # image.colorspace "Gray"
          image.format 'jp2' do |cb|
            cb.add_command('define', "jp2:rate=0.1")
            cb.add_command('define', "jp2:numrlvls=#{levels}")
          end
          result = temp_root.nil? ? Tempfile.new(["temp", ".jp2"]) : Tempfile.new(["temp", ".jp2"], temp_root)
          temp_path = result.path
          result.unlink
          result = File.open(temp_path, 'wb', 644)
          image.write result
          result.close
        end
        # convert $tiff -define jp2:rate=0.1 -define jp2:numrlvls=$levels $grayscale $jp2"
        # convert fixtures/spec/resources/CCITT_2.TIF -define jp2:rate=0.1 -define jp2:numrlvls=4 CCITT_2.jp2
      end
      result
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
  end
end
