# frozen_string_literal: true

desc "Generate gh-pages documentation site"

long_desc \
  "This tool generates an initial gh-pages documentation site.",
  "Note: gh-pages generation is experimental."

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
  def initialize(data)
    data.each { |name, value| instance_variable_set("@#{name}", value) }
    freeze
  end

  def self.get(data)
    new(data).instance_eval { binding }
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
  @relevant_component_settings = @settings.all_component_settings.find_all(&:gh_pages_enabled)
  if @relevant_component_settings.empty?
    puts "No components have gh-pages enabled", :red, :bold
    exit(1)
  end
end

def cleanup
  @artifact_dir.cleanup
end

CompInfo = ::Struct.new(:base_path, :regexp_source, :version_var)

def generate_gh_pages
  ::Dir.chdir(@gh_pages_dir) do
    @relevant_component_settings.each do |component_settings|
      generate_component_files(component_settings)
    end
    generate_toplevel_files
    generate_html404
  end
  puts "Files generated into #{@gh_pages_dir}", :bold
end

def generate_component_files(comp_settings)
  prepare_v0_directory("#{comp_settings.gh_pages_directory}/v0")
  generate_file("#{comp_settings.gh_pages_directory}/v0/index.html",
                "empty.html.erb", {name: comp_settings.name})
  component_redirect_url = "https://#{component_base_path(comp_settings)}/v#{current_component_version(comp_settings)}"
  generate_file("#{comp_settings.gh_pages_directory}/index.html",
                "redirect.html.erb", {redirect_url: component_redirect_url})
  generate_file("#{comp_settings.gh_pages_directory}/latest/index.html",
                "redirect.html.erb", {redirect_url: component_redirect_url})
end

def prepare_v0_directory(directory)
  ::FileUtils.mkdir_p(directory)
  children = ::Dir.children(directory) - ["index.html"]
  return if children.empty?
  puts "Non-index files exist in #{directory}.", :yellow, :bold
  return unless yes || confirm("Remove? ", default: true)
  children.each do |child|
    ::FileUtils.remove_entry(::File.join(directory, child), true)
  end
end

def current_component_version(comp_settings)
  base_dir = comp_settings.gh_pages_directory
  latest = ::Gem::Version.new("0")
  return latest unless ::File.directory?(base_dir)
  ::Dir.children(base_dir).each do |child|
    next unless /^v\d+(\.\d+)*$/.match?(child)
    next unless ::File.directory?(::File.join(base_dir, child))
    version = ::Gem::Version.new(child[1..])
    latest = version if version > latest
  end
  latest
end

def generate_toplevel_files
  ::File.write(".nojekyll", "")
  generate_file(".gitignore", "gitignore.erb", {})
  unless @relevant_component_settings.any? { |settings| settings.gh_pages_directory == "." }
    generate_file("index.html", "redirect.html.erb", {redirect_url: default_redirect_url})
  end
end

def generate_html404
  version_vars = {}
  replacement_info = @relevant_component_settings.map do |comp_settings|
    version_vars[comp_settings.gh_pages_version_var] = current_component_version(comp_settings)
    base_path = component_base_path(comp_settings)
    regexp_source = "//#{::Regexp.escape(base_path)}/latest(/|$)"
    CompInfo.new(base_path, regexp_source, comp_settings.gh_pages_version_var)
  end
  template_params = {
    default_redirect_url: default_redirect_url,
    version_vars: version_vars,
    replacement_info: replacement_info,
  }
  generate_file("404.html", "404.html.erb", template_params)
end

def url_base_path
  @url_base_path ||= "#{@settings.repo_owner}.github.io/#{@settings.repo_name}"
end

def component_base_path(component_settings)
  if component_settings.gh_pages_directory == "."
    url_base_path
  else
    "#{url_base_path}/#{component_settings.gh_pages_directory}"
  end
end

def default_redirect_url
  @default_redirect_url ||= "https://#{component_base_path(@relevant_component_settings.first)}/latest"
end

def generate_file(destination, template, data)
  return unless file_generation_confirmations(destination)
  template_path = find_data("gh-pages/#{template}")
  raise "Unable to find template #{template}" unless template_path
  erb = ::ERB.new(::File.read(template_path))
  content = erb.result(ErbContext.get(data))
  ::FileUtils.mkdir_p(::File.dirname(destination))
  ::File.write(destination, content)
  puts "Wrote #{destination}.", :green
end

def file_generation_confirmations(destination)
  if ::File.exist?(destination)
    if ::File.directory?(destination)
      puts "Destination #{destination} exists and is a DIRECTORY.", :yellow, :bold
    else
      puts "Destination file #{destination} exists.", :yellow, :bold
    end
    return false unless yes || confirm("Overwrite? ", default: true)
    ::FileUtils.remove_entry(destination)
  else
    return false unless yes || confirm("Create file #{destination}? ", default: true)
  end
  true
end

def push_gh_pages
  ::Dir.chdir(@gh_pages_dir) do
    if @repository.git_clean?
      puts "No changes made to gh-pages.", :yellow, :bold
      return
    end
    @repository.git_commit("Generated initial gh-pages", signoff: @settings.signoff_commits?)
    if dry_run
      puts "DRY RUN: Skipped git push.", :green, :bold
    else
      @utils.exec(["git", "push", git_remote, "gh-pages"], e: true)
      puts "Pushed gh-pages.", :green, :bold
    end
  end
end
