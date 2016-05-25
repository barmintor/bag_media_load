require 'active_support'
require 'cul_repo_cache'
require 'cul_foxml'
module BagIt
  extend ActiveSupport::Autoload
  eager_autoload do
    autoload :PairTree
    autoload :DcHelpers
    autoload :NameParser
    autoload :Info
    autoload :Manifest
    autoload :ImageHelpers
    autoload :Resource
    autoload :Bags
  end
  VERSION = '0.1.0'
  def self.exists?(pid)
    begin
      return ActiveFedora::Base.exists? pid
    rescue
      return false
    end
  end
  def self.next_pid(namespace="ldpd")
  	ActiveFedora::Base.fedora_connection[0] ||= ActiveFedora::RubydoraConnection.new(ActiveFedora.config.credentials)
    repo = ActiveFedora::Base.fedora_connection[0].connection
    pid = nil
    until pid
      pid = repo.mint(namespace: namespace)
      pid = nil if self.exists? pid
    end
    pid
  end
end
  
