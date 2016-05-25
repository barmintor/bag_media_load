require "active-fedora"
require 'jettywrapper'
require "cul_hydra"

Jettywrapper.url = "https://github.com/projecthydra/hydra-jetty/archive/7.x-stable.zip"
namespace :bag do
  task :logger do
    @logger = ActiveSupport::Logger.new($stdout)
  end
  task cmodels: :environment do
    task = Rake::Task["cul_hydra:cmodel:reload_all"]
    logger = ActiveSupport::Logger.new($stdout)
    task.scope.instance_variable_set(:@logger, logger)
    task.instance_variable_set(:@logger, logger)
    task.invoke
  end
  task ci: 'rubocop' do
    ENV['RAILS_ENV'] = 'test'
    Rails.env = ENV['RAILS_ENV']

    @logger = Rails.logger
    Jettywrapper.jetty_dir = File.join(Rails.root, 'jetty-test')

    unless File.exists?(Jettywrapper.jetty_dir)
      puts "\n"
      puts 'No test jetty found.  Will download / unzip a copy now.'
      puts "\n"
    end

    Rake::Task["jetty:clean"].invoke

    jetty_params = Jettywrapper.load_config.merge({jetty_home: Jettywrapper.jetty_dir})
    error = Jettywrapper.wrap(jetty_params) do
      Rake::Task["bag:cmodels"].invoke
      Rake::Task["db:drop"].invoke
      Rake::Task["db:create"].invoke
      Rake::Task["db:migrate"].invoke
      Rake::Task["db:seed"].invoke
      Rake::Task['coverage'].invoke
    end
    raise "test failures: #{error}" if error
  end
end
