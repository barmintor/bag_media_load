require "rake"
require "active-fedora"
require "cul_scv_hydra"
require "nokogiri"
require "bag_it"
require "open-uri"
include Cul::Repo::Constants

def get_ldpd_content_pid
  BagAggregator.find_by_identifier(LDPD_PROJECTS_ID)
end

def get_bag_pid(bag_id)
  BagAggregator.find_by_identifier(bag_id)
end

def rubydora
  ActiveFedora::Base.fedora_connection[0] ||= ActiveFedora::RubydoraConnection.new(ActiveFedora.config.credentials)
  ActiveFedora::Base.fedora_connection[0].connection
end

def next_pid
  BagIt.next_pid
end

namespace :pids do
  desc "generate derivatives for the list of pids"
  task :derivatives  => :environment do
    pid_list = ENV['PID_LIST']
    # parse bag-info for external-id and title
    lines = ""
    ctr = 0
    total = 0
    open (pid_list) do |blob|
      total = blob.readlines.size
    end
    open(pid_list) do |blob|
    	blob.each do |pid|
        pid = pid.strip
        ctr += 1
    	obj = GenericResource.find(pid)
        begin
          jp2 = obj.datastreams['zoom']
          rels_int = obj.rels_int
          if jp2
            if jp2.mimeType != 'image/jp2'
              jp2.mimeType = 'image/jp2'
            end
            if jp2.label != 'zoom.jp2'
              jp2.dsLabel = 'zoom.jp2'
            end
          end
          obj.save
          unless jp2.nil?
            jp2w = 0
            unless rels_int.relationships(jp2,:image_width).blank? 
              jp2w = rels_int.relationships(jp2,:image_width).first.object.to_s.to_i
            end
            if jp2w == 0
              rels_int.clear_relationship(jp2, GenericResource::WIDTH)
              width = obj.send :width
              rels_int.add_relationship(jp2, GenericResource::WIDTH, width.to_s, true)
              rels_int.clear_relationship(jp2, GenericResource::LENGTH)
              length = obj.send :length
              rels_int.add_relationship(jp2, GenericResource::LENGTH, length.to_s, true)
              rels_int.clear_relationship(jp2, GenericResource::FORMAT)
              rels_int.add_relationship(jp2, GenericResource::FORMAT, 'image/jp2', true)
              rels_int.serialize!
            end
          end
          obj.derivatives!
          Rails.logger.info("#{ctr} of #{total}: success")
        rescue Exception => e
          Rails.logger.info("#{ctr} of #{total}: failure")
          Rails.logger.error(e.message)
        end
      end
    end
  end
end
