module Cul::Repo::Constants
  LDPD_PROJECTS_ID = 'http://libraries.columbia.edu/projects/aggregation'
  LDPD_STORAGE_ID = 'apt://columbia.edu'
  def self.projects_admin_set
  	AdministrativeSet.search_repo(identifier: LDPD_PROJECTS_ID).first
  end
  def self.rubydora
    ActiveFedora::Base.fedora_connection[0] ||= ActiveFedora::RubydoraConnection.new(ActiveFedora.config.credentials)
    ActiveFedora::Base.fedora_connection[0].connection
  end
end