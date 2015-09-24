require "rake"
require "active-fedora"
require "cul_hydra"
require "nokogiri"
require 'cul_repo_cache'
require "bag_it"
require "arxv"

namespace :bagit do
  task :entries do
  	bag_path = ENV['BAG']
  	bag_info = BagIt::Info.new(bag_path)
    manifest = bag_info.manifest(ENV['ALG'] || 'sha512')
    ctr = 0
    manifest.each_entry do |entry|
      source = entry.path
      rel_path = "data/" + source.split(/\/data\//)[1..-1].join('/data/')
      puts("#{ctr += 1 } #{rel_path}")
    end
  end
end