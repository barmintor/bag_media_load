require "rake"
require "active-fedora"
require "cul_scv_hydra"

namespace :migrate do
  task :list => :environment do
    open(ENV['PID_LIST']) do |blob|
      blob.each do |line|
        pid = line
        pid.strip!
        obj = GenericResource.find(pid)
        if obj
          obj.migrate!
        end
      end
    end
  end
end