require 'rubygems'
require 'rake'
require 'rake/clean'

CLEAN << FileList['**/*.rbc']

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name = "nbtfile"
    gem.summary = %Q{nbtfile provides a low-level API for reading and writing files using Minecraft's NBT serialization format}
    gem.description = %Q{Library for reading and writing NBT files (as used by Minecraft).}
    gem.email = "mental@rydia.net"
    gem.homepage = "http://github.com/mental/nbtfile"
    gem.authors = ["MenTaLguY"]
    gem.add_development_dependency "rspec", ">= 2.0"
    # gem is a Gem::Specification... see http://www.rubygems.org/read/chapter/20 for additional settings
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler (or a dependency) not available. Install it with: gem install jeweler"
end

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec) do |spec|
  spec.rspec_opts = "--color"
end

RSpec::Core::RakeTask.new(:rcov) do |spec|
  spec.rspec_opts = "--color"
  spec.rcov = true
end

task :spec => :check_dependencies

task :specs => :spec

task :default => :spec

require 'rake/rdoctask'
Rake::RDocTask.new do |rdoc|
  version = File.exist?('VERSION') ? File.read('VERSION') : ""

  rdoc.main = 'README.rdoc'
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "nbtfile #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end
