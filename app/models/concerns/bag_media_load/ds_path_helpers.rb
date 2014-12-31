require 'uri' 
module BagMediaLoad::DsPathHelpers
  extend ActiveSupport::Concern
  def path_to_ds_uri(path)
    uri = File.absolute_path(path)
    uri = uri.split(File::SEPARATOR)
    uri[1..-1].collect{|x| URI.escape(x)}.unshift("file:").join('/')
  end
  def ds_uri_to_path(dsLocation)
    # don't mess with non-file URIs
    if dsLocation =~ /^file:\//
      dsLocation = dsLocation.sub(/^file:\/+/,'/')
      dsLocation = URI.unescape(dsLocation)
    end
    dsLocation
  end
  def mime_for_name(filename)
    ext = File.extname(File.basename(filename)).downcase
    mt = MIME::Types.type_for(ext)
    if mt.is_a? Array
      mt = mt.first
    end
    unless mt.nil?
      return mt.content_type
    else
      return nil
    end
  end
end