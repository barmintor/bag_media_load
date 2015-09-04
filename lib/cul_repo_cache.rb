module Cul
  module Repo
    autoload :Constants, 'cul/repo/constants'
    autoload :Load, 'cul/repo/load'
    module Serializers
      require 'cul/repo/serializers/struct_metadata'
    end
    module Cache
      autoload :DerivativeInfo, 'cul/repo/cache/derivative_info'
      autoload :Path, 'cul/repo/cache/path'
    end
  end
end