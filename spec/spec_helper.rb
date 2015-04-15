require 'yaml'
ENV["environment"] ||= 'test'
ENV["RAILS_ENV"] ||= 'test'
require File.expand_path("../../config/environment", __FILE__)
require 'rspec/rails'
require 'pathname'
require 'bag_it'
require 'arxv'
require 'tempfile'
require 'cul_image_props'

RSpec.configure do |config|
  config.mock_with :mocha
end
unless PronomFormat.exists?('fmt/18')
	load "#{Rails.root}/db/seeds.rb"
end

def path_to_fixture(file)
  path = File.join(File.dirname(__FILE__), '..','fixtures','spec', file)
  raise "No fixture file at #{path}" unless File.exists? path
  return path
end

def fixture(file)
  File.new(path_to_fixture(file))
end

def yaml(file)
  return YAML.load_file(fixture(file))
end