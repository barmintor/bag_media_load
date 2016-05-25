#!/usr/bin/env rake
# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

require File.expand_path('../config/application', __FILE__)

BagMediaLoad::Application.load_tasks

begin
  # This code is in a begin/rescue block so that the Rakefile is usable
  # in an environment where RSpec is unavailable (i.e. production).

  require 'rspec/core/rake_task'

  RSpec::Core::RakeTask.new(rspec: ['bag:media:seed']) do |spec|
    spec.pattern = FileList['spec/**/*_spec.rb']
    spec.pattern += FileList['spec/*_spec.rb']
    spec.rspec_opts = ['--backtrace'] if ENV['CI']
  end

  RSpec::Core::RakeTask.new(:coverage) do |_spec|
    ruby_engine = defined?(RUBY_ENGINE) ? RUBY_ENGINE : "ruby"
    ENV['COVERAGE'] = 'true' unless ruby_engine == 'jruby'

    Rake::Task["rspec"].invoke
  end

  require 'rubocop/rake_task'
  desc 'Run style checker'
  RuboCop::RakeTask.new(:rubocop) do |task|
    task.requires << 'rubocop-rspec'
    task.fail_on_error = true
  end

rescue LoadError => e
  puts "[Warning] Exception creating dev rake tasks.  This message can be ignored in environments that intentionally do not pull in the RSpec gem (i.e. production)."
  puts e
end

task default: 'bag:ci'
