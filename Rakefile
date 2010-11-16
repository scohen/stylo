require 'rubygems'
require 'rake'
require 'rspec/core/rake_task'

desc 'Default: run specs.'
task :default => :spec

desc 'Run the specs'
RSpec::Core::RakeTask.new(:spec) do |t|
  t.rspec_opts = ['--colour --format progress']
end
