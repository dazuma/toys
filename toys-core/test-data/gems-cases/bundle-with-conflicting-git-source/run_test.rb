# frozen_string_literal: true

require "fileutils"
require "tmpdir"
require "toys-core"
require "toys/utils/gems"

# Load a gem for real, so the check compares against a genuine Gem.loaded_specs
# entry rather than a spec the test synthesized.
require "logger"
raise "logger is not loaded" unless Gem.loaded_specs.key?("logger")

Dir.mktmpdir do |dir|
  # A real git repository, never checked out into a bundle. Bundler cannot
  # resolve a revision for it from a Bundler::Dsl, which is exactly the state
  # the check runs in.
  repo = File.join(dir, "logger-repo")
  FileUtils.mkdir_p(repo)
  File.write(File.join(repo, "README"), "fixture\n")
  Dir.chdir(repo) do
    system("git", "init", "--quiet", ".", exception: true)
    system("git", "add", "-A", exception: true)
    system("git", "-c", "user.email=t@example.com", "-c", "user.name=toys",
           "commit", "--quiet", "-m", "fixture", exception: true)
  end

  gemfile = File.join(dir, "Gemfile")
  File.write(gemfile, <<~GEMFILE)
    source "https://rubygems.org"
    gem "logger", git: #{repo.inspect}
  GEMFILE

  # The real entry point: bundle -> setup_bundle -> check_gemfile_compatibility,
  # with Bundler.configure and the live Bundler UI, and sources built by the
  # production code rather than by the caller.
  begin
    Toys::Utils::Gems.new(on_missing: :error).bundle(gemfile_path: gemfile)
    puts "no-conflict"
  rescue Toys::Utils::Gems::IncompatibleGemSourceError => e
    puts "conflict: #{e.message}"
  end
end
