require "bundler/gem_tasks"
require "rake/testtask"
require "yard"
require "yard/rake/yardoc_task"
require "shellwords"
require "toys"

CLEAN << ["pkg", "doc"]

::Rake::TestTask.new do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = ::FileList["test/*_test.rb"]
end

::YARD::Rake::YardocTask.new

task :run, :args do |t, args|
  args = Shellwords.split(args[:args] || "")
  Toys::Cli.create_standard.run(args)
end

task :install => :build do
  sh "gem install pkg/toys-#{Toys::VERSION}.gem "
end

task :default => [:test]
