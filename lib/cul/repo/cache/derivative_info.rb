module Cul::Repo::Cache::DerivativeInfo
  extend ActiveSupport::Concern
  JP2_DEFAULT_DATASTREAM_NAME = 'zoom'
  THUMBNAIL_DEFAULT_DATASTREAM_NAME = 'thumbnail'

  STATUS_QUEUED = :queued

  TYPE_SQUARE = :square
  TYPE_SCALED = :scaled
  TYPE_ZOOM = JP2_DEFAULT_DATASTREAM_NAME.to_sym
  VALID_TYPE_OPTIONS = [TYPE_SQUARE, TYPE_SCALED, TYPE_ZOOM]

  SCALED_SIZES = APP_CONFIG[TYPE_SCALED]['sizes'] # Scales longest side to one of these values
  LARGE_SCALED_SIZE = SCALED_SIZES.max # Used for creating smaller derivatives because it's faster than using the original resource
  THUMBNAIL_SCALED_SIZE = SCALED_SIZES.min # Used for creating smaller derivatives because it's faster than using the original resource
  SCALED_SIZES_TO_STORE_IN_FEDORA = [THUMBNAIL_SCALED_SIZE, LARGE_SCALED_SIZE]

  SQUARE_SIZES = APP_CONFIG[TYPE_SQUARE]['sizes'] # Scales cropped square size to one of these values
  LARGE_SQUARE_SIZE = SQUARE_SIZES.max # Used for creating smaller derivatives because it's faster than using the original resource
  SQUARE_SIZES_TO_STORE_IN_FEDORA = [] # We're not storing any square thumbnails in Fedora

  VALID_DERIVATIVE_FILE_FORMATS = {'png' => 'image/png', 'jpg' => 'image/jpeg', 'jp2' => 'image/jp2'}

  module ClassMethods
    def get_closest_number(requested_number, array_of_numbers)
      closest = nil
      array_of_numbers = array_of_numbers.sort do |x,y|
        (x - requested_number).abs <=> (y - requested_number).abs
      end
      array_of_numbers.first
    end
    def get_representative_generic_resource(id)

      obj = ActiveFedora::Base.find(id)
      return obj if obj.is_a?(GenericResource)

      # If we're here, then the object was not a Generic resource.
      # Try to get child info from a structMat datastream, and fall back to
      # the first child if a structMap isn't present

      # Check for the presence of a structMap and get first GenericResource in that structMap
      if obj.has_struct_metadata?

        struct = Cul::Scv::Hydra::Datastreams::StructMetadata.from_xml(obj.datastreams['structMetadata'].content)
        ng_div = struct.first_ordered_content_div #Nokogiri node response
        content_ids = ng_div.attr('CONTENTIDS').split(' ') # Get all space-delimited content ids
        child_obj = GenericAggregator.search_repo.find_by(identifier: content_ids[0]) # We don't know what type of aggregator we'll be getting back, but all we need is the pid

        return get_representative_generic_resource(child_obj.pid)
      else
        # If there isn't a structMap, just get the first child
        member_pids = Cul::Scv::Hydra::RisearchMembers.get_direct_member_pids(id)
        return get_representative_generic_resource(member_pids.first)
      end
    end
  end
end
