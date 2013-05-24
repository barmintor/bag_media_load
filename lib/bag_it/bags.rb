require 'active_support'
module BagIt
	module Bags
      extend ActiveSupport::Autoload
        eager_autoload do
          autoload :DefaultBag
          autoload :CssBag
        end
    end
end
