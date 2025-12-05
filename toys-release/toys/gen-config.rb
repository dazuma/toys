# frozen_string_literal: true

desc "Generate an initial config file"

long_desc \
  "This tool generates an initial config file for this repo." \
    " You will generally need to make additional edits to this file after" \
    " initial generation."

flag :repo, "--repo=REPO" do
  desc "GitHub repo owner and name (e.g. dazuma/toys)"
end
flag :git_user, "--git-user=NAME" do
  default ""
  desc "User name for git commits (defaults to the git user.name config)"
end
flag :git_email, "--git-email=NAME" do
  default ""
  desc "User email for git commits (defaults to the git user.email config)"
end
flag :file_path, "-o PATH", "--output=PATH" do
  desc "Output file path (defaults to .toys/.data/releases.yml)"
end
flag :yes, "--yes", "-y" do
  desc "Automatically answer yes to all confirmations"
end

include :exec, e: true
include :terminal, styled: true
include :fileutils

def run
  setup
  interpret_github_repo
  interpret_git_user
  check_file_path
  gems_and_dirs = find_gems
  confirm_with_user
  mkdir_p(::File.dirname(file_path))
  ::File.open(file_path, "w") do |file|
    write_settings(file, gems_and_dirs)
  end
  puts("Wrote initial config file to #{file_path}.", :green, :bold)
end

def setup
  require "toys/release/environment_utils"
  @utils = Toys::Release::EnvironmentUtils.new(self)
  cd(@utils.repo_root_directory)
end

def interpret_github_repo
  return if repo
  current_guess = nil
  capture(["git", "remote", "-v"]).split("\n").each do |line|
    match = %r{^(\S+)\s+git@github\.com:([^/.\s]+/[^/.\s]+)(?:\.git)?}.match(line)
    current_guess = match[2] if match && (match[1] == "origin" || current_guess.nil?)
    match = %r{^(\S+)\s+https://github\.com/([^/.\s]+/[^/.\s]+)(?:\.git)?}.match(line)
    current_guess = match[2] if match && (match[1] == "origin" || current_guess.nil?)
  end
  if current_guess.nil?
    puts "Unable to determine the GitHub repo associated with this repository.", :red, :bold
    exit(1)
  end
  puts "GitHub repository inferred to be #{current_guess}."
  puts "If this is incorrect, specify the correct repo using the --repo= flag."
  set(:repo, current_guess)
end

def interpret_git_user
  if git_user.empty?
    set(:git_user, capture(["git", "config", "get", "user.name"]).strip)
    if git_user.empty?
      puts "Unable to determine git user.name. Using a hard-coded fallback", :yellow
      set(:git_user, "Example User")
    else
      puts "Using the current git user.name of #{git_user}"
    end
  end
  if git_email.empty?
    set(:git_email, capture(["git", "config", "get", "user.email"]).strip)
    if git_email.empty?
      puts "Unable to determine git user.email. Using a hard-coded fallback", :yellow
      set(:git_email, "hello@example.com")
    else
      puts "Using the the current git user.email of #{git_email}"
    end
  end
end

def check_file_path
  set(:file_path, ::File.join(".toys", ".data", "releases.yml")) unless file_path
  if ::File.readable?(file_path)
    puts "Cannot overwrite existing file: #{file_path}", :red, :bold
    exit(1)
  end
end

def confirm_with_user
  exit unless yes || confirm("Create config file #{file_path}? ", default: true)
end

def find_gems
  toplevel = ::Dir.glob("*.gemspec")
  subdirs = ::Dir.glob("*/*.gemspec")
  if toplevel.size > 1
    puts "Unexpected: Found multiple gemspecs at the top level.", :red, :bold
    exit(1)
  end
  if toplevel.size == 1 && subdirs.empty?
    path = toplevel.first
    puts "Found #{path} at the toplevel of the repo."
    [[::File.basename(path, ".gemspec"), "."]]
  elsif toplevel.empty? && !subdirs.empty?
    subdirs.map do |path|
      puts "Found #{path} in the repo."
      [::File.basename(path, ".gemspec"), ::File.dirname(path)]
    end
  else
    puts "Unexpected: Found gemspecs at the toplevel and in subdirectories.", :red, :bold
    exit(1)
  end
end

def write_settings(file, gems_and_dirs)
  file.puts("repo: #{repo}")
  file.puts("git_user_name: #{git_user}")
  file.puts("git_user_email: #{git_email}")
  file.puts("# Insert additional repo-level settings here.")
  file.puts
  file.puts("gems:")
  gems_and_dirs.sort_by(&:first).each do |(name, dir)|
    file.puts("  - name: #{name}")
    file.puts("    directory: #{dir}")
    file.puts("    # Insert additional gem-level settings here.")
  end
end
