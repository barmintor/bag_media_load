require "active-fedora"
require "cul_image_props"
require "mime/types"
require "net/http"
require "uri"
require "open-uri"
require "tempfile"
require "bag_it"
class GenericResource < ::ActiveFedora::Base
  extend ActiveModel::Callbacks
  include ::ActiveFedora::FinderMethods::RepositoryMethods
  include ::ActiveFedora::DatastreamCollections
  include ::Hydra::ModelMethods
  include Cul::Scv::Hydra::Models::Common
  include Cul::Scv::Hydra::Models::ImageResource
  include Cul::Scv::Fedora::UrlHelperBehavior
  include BagIt::DcHelpers
  include BagIt::Resource
  include ::ActiveFedora::RelsInt
  include BagMediaLoad::DsPathHelpers
  include BagMediaLoad::ImageSourceHelpers
  include BagMediaLoad::MigrationHelpers

  def container_uris_for(obj,obs=false)
    r = obj.relationships(:cul_member_of)
    if obs # clean up from failed runs previous
      r += obj.relationships(:cul_obsolete_from)
    end
    r
  end
end