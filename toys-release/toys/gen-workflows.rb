# frozen_string_literal: true

desc "Generate GitHub Actions workflow files"

long_desc \
  "This tool generates workflow files for GitHub Actions."

flag :workflows_dir, "-o PATH", "--output=PATH" do
  desc "Output directory (defaults to .github/workflows)"
end
flag :yes, "--yes", "-y" do
  desc "Automatically answer yes to all confirmations"
end

include :exec, e: true
include :terminal, styled: true
include :fileutils

# Context for ERB templates
class ErbContext
  def initialize(settings)
    @settings = settings
  end

  def self.get(settings)
    new(settings).instance_eval { binding }
  end
end

def run
  setup
  user_confirmation
  generate_all_files
end

def setup
  require "erb"
  require "fileutils"
  require "toys/release/environment_utils"
  require "toys/release/repo_settings"

  @utils = Toys::Release::EnvironmentUtils.new(self)
  cd(@utils.repo_root_directory)
  @settings = Toys::Release::RepoSettings.load_from_environment(@utils)

  set(:workflows_dir, ::File.join(".github", "workflows")) if workflows_dir.to_s.empty?
end

def user_confirmation
  unless @settings.enable_release_automation?
    puts "Release automation disabled in settings."
    unless yes || confirm("Create workflow files anyway? ", default: false)
      @utils.error("Aborted.")
    end
  end
end

def generate_all_files
  mkdir_p(workflows_dir)
  files = [
    "release-hook-on-closed.yml",
    "release-hook-on-push.yml",
    "release-perform.yml",
    "release-request.yml",
    "release-retry.yml",
  ]
  files.each { |name| generate_file(name) }
  puts "Workflow files generated.", :green, :bold
end

def generate_file(name)
  template_path = find_data("templates/#{name}.erb")
  raise "Unable to find template #{name}.erb" unless template_path
  erb = ::ERB.new(::File.read(template_path))
  content = erb.result(ErbContext.get(@settings))

  destination = ::File.join(workflows_dir, name)
  stat = safe_lstat(destination)
  if stat
    if stat.file? && safe_read(destination) == content
      puts "Unchanged: #{destination}.", :green
      return
    end
    puts "Destination #{destination} exists (type: #{stat.ftype})", :yellow, :bold
    return unless yes || confirm("Overwrite? ", default: true)
  else
    return unless yes || confirm("Create file #{destination}? ", default: true)
  end

  ::FileUtils.remove_entry(destination, true)
  ::File.write(destination, content)
  puts "Wrote #{destination}.", :green
end

def safe_lstat(path)
  ::File.lstat(path)
rescue ::SystemCallError
  nil
end

def safe_read(path)
  ::File.read(path)
rescue ::SystemCallError
  nil
end
