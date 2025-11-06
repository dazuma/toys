# frozen_string_literal: true

desc "Generate gh-pages documentation site"

long_desc "This tool generates an initial gh-pages documentation site."

flag :working_dir, "--working-dir=PATH" do
  desc "Set the working directory for the gh-pages checkout"
end
flag :git_remote, "--git-remote=REMOTE" do
  desc "Use the specified remote (default is `origin`)"
  default "origin"
end
flag :yes, "--yes", "-y" do
  desc "Automatically answer yes to all confirmations"
end
flag :dry_run

include :exec
include :terminal, styled: true

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
  generate_gh_pages
  push_gh_pages
  cleanup
end

def setup
  require "erb"
  require "fileutils"
  require "toys/release/artifact_dir"
  require "toys/release/environment_utils"
  require "toys/release/repo_settings"
  require "toys/release/repository"

  ::Dir.chdir(context_directory)
  @utils = Toys::Release::EnvironmentUtils.new(self)
  @settings = Toys::Release::RepoSettings.load_from_environment(@utils)
  @repository = Toys::Release::Repository.new(@utils, @settings)
  @artifact_dir = Toys::Release::ArtifactDir.new(working_dir)
  @gh_pages_dir = @repository.checkout_separate_dir(
    branch: "gh-pages", remote: git_remote, dir: @artifact_dir.get("gh-pages"),
    gh_token: ::ENV["GITHUB_TOKEN"], create: true
  )
end

def cleanup
  @artifact_dir.cleanup
end

def generate_gh_pages
  ::Dir.chdir(@gh_pages_dir) do
    ::File.write(".nojekyll", "")
    generate_file("gh-pages-gitignore.erb", ".gitignore")
    generate_file("gh-pages-404.html.erb", "404.html") do |content, old_content|
      update_versions(content, old_content)
    end
    generate_file("gh-pages-index.html.erb", "index.html")
    @settings.all_component_settings.each do |component_settings|
      generate_file("gh-pages-empty.html.erb", "#{component_settings.gh_pages_directory}/v0.0.0/index.html",
                    settings: component_settings, remove_dir: true)
    end
  end
  puts "Files generated into #{@gh_pages_dir}", :bold
end

def push_gh_pages
  ::Dir.chdir(@gh_pages_dir) do
    @repository.git_commit("Generated initial gh-pages", signoff: @settings.signoff_commits?)
    if dry_run
      puts "DRY RUN: Skipped git push.", :green, :bold
    else
      @utils.exec(["git", "push", git_remote, "gh-pages"], e: true)
      puts "Pushed gh-pages.", :green, :bold
    end
  end
end

def generate_file(template, destination, settings: nil, remove_dir: false)
  old_content = file_generation_confirmations(destination, remove_dir)
  return if old_content == :cancel
  template_path = find_data("templates/#{template}")
  raise "Unable to find template #{template}" unless template_path
  erb = ::ERB.new(::File.read(template_path))
  content = erb.result(ErbContext.get(settings || @settings))
  content = yield(content, old_content) if block_given? && old_content
  ::File.write(destination, content)
  puts "Wrote #{destination}."
end

def file_generation_confirmations(destination, remove_dir)
  old_content = nil
  if ::File.readable?(destination)
    old_content = ::File.read(destination)
    puts "Destination file #{destination} exists.", :yellow, :bold
    return :cancel unless yes || confirm("Overwrite? ", default: true)
  else
    return :cancel unless yes || confirm("Create file #{destination}? ", default: true)
  end
  dir = ::File.dirname(destination)
  unless dir == "."
    if remove_dir && ::File.directory?(dir)
      puts "Old version directory #{dir} exists.", :yellow, :bold
      return :cancel unless yes || confirm("Remove? ", default: true)
      ::FileUtils.remove_entry(dir, true)
    end
    ::FileUtils.mkdir_p(dir)
  end
  old_content
end

def update_versions(content, old_content)
  @settings.all_component_settings.each do |component_settings|
    match = /#{component_settings.gh_pages_version_var} = "([\w.]+)";/.match(old_content)
    if match
      content.sub!("#{component_settings.gh_pages_version_var} = \"0.0.0\";",
                   "#{component_settings.gh_pages_version_var} = \"#{match[1]}\";")
    end
  end
  content
end
