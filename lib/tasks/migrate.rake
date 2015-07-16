require "rake"
require "active-fedora"
require "cul_hydra"
require "mime/types"

def unique_pids(search_response)
    (search_response['results'] || []).map{|result| result['pid'].gsub('info:fedora/', '') }.uniq
end
def mimes_for(dsLocation)
  MIME::Types.type_for(File.ext(dsLocation))
end
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
  task :types => :environment do
    query = 'select $pid from <#ri> ' +
            'where $pid <fedora-model:hasModel> <fedora:ldpd:GenericResource> ' +
            'and $pid <dc:type> \'Image\''
    ri_opts = {
      :type => 'tuples',
      :format => 'json',
      :limit => '100',
      :stream => 'on'
    }
    search_response = JSON(Cul::Hydra::Fedora.repository.find_by_itql(query, ri_opts))
    ctr = 0
    while (pids = unique_pids(search_response)).first
      pids.each do |pid|
        gr = GenericResource.find(pid)
        content = gr.datastreams['content']
        ctr += 1
        image = content.mimeType.start_with? 'image'
        unless image
          mimes_for(content.dsLocation).each {|mt| image ||= mt.start_with? 'image'}
        end
        if image
          gr.datastreams["DC"].update_values({[:dc_type] => 'StillImage'})
        else
          gr.datastreams["DC"].update_values({[:dc_type] => 'Software'})
        end
        gr.datastreams["DC"].content_will_change!
        gr.save
        Rails.logger.info "#{ctr} dc:type = #{image ? 'StillImage' : 'Software'}"
      end
      sleep 10
      search_response = JSON(Cul::Hydra::Fedora.repository.find_by_itql(query, ri_opts))
    end
  end
end