# drop the lib directory into the load path
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require "bundler/gem_tasks"
require "rspec/core/rake_task"
require "coveralls/rake/task"

import(*Dir.glob("./lib/rack/params/**/*.rake"))

CLOBBER << "docs"
CLOBBER << "coverage"

RSpec::Core::RakeTask.new(:spec)
Coveralls::RakeTask.new

task :default => :spec
