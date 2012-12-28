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
  def self.next_pid
  	ActiveFedora::Base.fedora_connection[0] ||= ActiveFedora::RubydoraConnection.new(ActiveFedora.config.credentials)
    repo = ActiveFedora::Base.fedora_connection[0].connection
    pid = nil
	repo = fedora
	begin
	  pid = repo.next_pid(:namespace=>namespace)
	end while ActiveFedora::Base.exists? pid
	pid
  end
end
  
  
