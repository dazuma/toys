require "bundler/gem_tasks"
require "rake/testtask"
require "yard"
require "yard/rake/yardoc_task"

CLEAN << ["pkg", "doc"]

::Rake::TestTask.new do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = ::FileList["test/*_test.rb"]
end

::YARD::Rake::YardocTask.new

task :default => [:test]
