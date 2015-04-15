module BagMediaLoad::ImageSourceHelpers
  extend ActiveSupport::Concern
  module ClassMethods
    OCTETSTREAM = "application/octet-stream"
    # valid EXIF Rotation values are 1,2,3,4,5,6,7,8
    # but 2,4,5,7 represent horizontal flipping that is undetectable ex post facto
    # without recourse to the photographed object, so treat as closest fit
    DEROTATION_OFFSET = {1 => 0, 2 => 0, 3 => 180, 4 => 180,  5=> 90, 6 => 90, 7=> 270, 8 => 270}
    
    def image_properties(path)
      if block_given?
        Imogen.with_image(path) do |img|
          yield :image_width, img.width, true
          yield :image_length, img.height, true
          yield :extent, File.size(path), true
          format = Imogen.format_from(path)
          unless format == :unknown
            format = MIME::Types.type_for(format.to_s)
            if format && format.first
              format = format.first.content_type
            else
              format = :unknown
            end
          end
          format = OCTETSTREAM unless (format && format != :unknown)

          yield :format, format, true
        end
      else
        properties = {}
        image_properties(path) do |pred_key, value, literal|
          properties[pred_key] = value
        end
        properties
      end
    end
  end
  def image_blob(dsLocation)
    img = Magick::Image.ping(dsLocation)
    img = Array(img).first
    img
  end

  def with_original_image(flags=0, &block)
    path = datastreams['content'].dsLocation
    Imogen.with_image(@path, flags, &block)
  end

  def image_rels(path, ds)
    GenericResource.image_properties(path) do |k,v,literal|
      rels_int.clear_relationship(ds, k)
      rels_int.add_relationship(ds, k, v, literal)
    end
  end

  def derivative_url(opts={})
    opts = {size:1, id: self.pid, type: 'scaled', format:'jpg'}.merge(opts)
    "#{IMG_CONFIG['base']}/#{opts[:id]}/#{opts[:type]}/#{opts[:size]}.#{opts[:format]}"
  end

  def tempfile(name_parts, temp_root='/var/tmp/bag_media_load')
    Tempfile.new(name_parts, temp_root)
  end


  private
  def long
    @long_side ||= max(width(), length())
  end

  def width
    @width ||= begin
      ds = datastreams["content"]
      width = 0
      unless rels_int.relationships(ds,:image_width).blank?
        width = rels_int.relationships(ds,:image_width).first.object.to_s.to_i
      end
      width = relationships(:cul_image_width).first.to_s.to_i if width == 0
      width
    end
  end

  def length
    @length ||= begin
      ds = datastreams["content"]
      length = 0
      unless rels_int.relationships(ds,:image_length).blank?
        length = rels_int.relationships(ds,:image_length).first.object.to_s.to_i
      end
      length = relationships(:cul_image_length).first.to_s.to_i if length == 0
      length
    end
  end

end