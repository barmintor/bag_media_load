require 'yaml'
ENV["environment"] ||= 'test'
ENV["RAILS_ENV"] ||= 'test'
$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'app','models'))
libs = File.expand_path(File.dirname(__FILE__) + '/../lib/*.rb')
require 'bag_it'

RSpec.configure do |config|
  config.mock_with :mocha
end

def fixture(file)
  path = File.join(File.dirname(__FILE__), '..','fixtures','spec', file)
  raise "No fixture file at #{path}" unless File.exists? path
  File.new(path)
end

def yaml(file)
  return YAML.load(fixture(file))
end