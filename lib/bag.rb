require 'active_support'
module Bag
  extend ActiveSupport::Autoload
  eager_autoload do
    autoload :DcHelpers
    autoload :Info
    autoload :Manifest
    autoload :ImageHelpers
    autoload :ResourceTypes
  end
  VERSION = '0.1.0'
end
  
  
