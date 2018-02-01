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
  t.test_files = ::FileList["test/test_*.rb"]
end

::YARD::Rake::YardocTask.new

task :run, :args do |t, args|
  args = Shellwords.split(args[:args])
  toys = Toys::Exec.new(include_builtin: true)
  toys.run(args)
end

task :install => :build do
  sh "gem install pkg/toys-#{Toys::VERSION}.gem "
end

task :default => [:test]
