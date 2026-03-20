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

def run
  setup
  generate_gh_pages
  push_gh_pages
  cleanup
end

def setup
  require "toys/release/artifact_dir"
  require "toys/release/environment_utils"
  require "toys/release/gh_pages_logic"
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
  if @settings.all_component_settings.none?(&:gh_pages_enabled)
    puts "No components have gh-pages enabled", :red, :bold
    exit(1)
  end
  @template_dir = find_data("gh-pages", type: :directory)
  raise "Fatal: Unable to find gh-pages template data directory" unless @template_dir
  @logic = Toys::Release::GhPagesLogic.new(@settings)
end

def cleanup
  @artifact_dir.cleanup
end

def generate_gh_pages
  @logic.cleanup_v0_directories(@gh_pages_dir) do |directory, _children|
    puts "Non-index files exist in #{directory}.", :yellow, :bold
    yes || confirm("Remove? ", default: true)
  end
  results = @logic.generate_files(@gh_pages_dir, @template_dir) do |destination, status, existing_ftype|
    if status == :overwrite
      puts "Destination #{destination} exists (type: #{existing_ftype})", :yellow, :bold
      yes || confirm("Overwrite? ", default: true)
    else
      yes || confirm("Create file #{destination}? ", default: true)
    end
  end
  output_results(results)
end

def output_results(results)
  results.each do |r|
    case r[:outcome]
    when :wrote
      puts "Wrote #{r[:destination]}.", :green
    when :unchanged
      puts "Unchanged: #{r[:destination]}.", :green
    when :skipped
      puts "Skipped: #{r[:destination]}.", :yellow
    end
  end
  puts "Files generated into #{@gh_pages_dir}", :bold
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
