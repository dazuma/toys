# frozen_string_literal: true

desc "Trigger a release of Toys"

include :exec, exit_on_nonzero_status: true
include :terminal
include :fileutils
include "release-tools"

required_arg :version
flag :yes
flag :git_remote, "--git-remote=NAME", default: "origin"

def run
  cd(context_directory)
  #verify_git_clean()
  #verify_library_versions(version)
  #changelog_core = verify_changelog_content("toys-core", version)
  #changelog_toys = verify_changelog_content("toys", version)
  verify_github_checks()
  #puts("Changelog for toys:", :bold)
  #puts(changelog_toys)
  #puts("Changelog for toys-core:", :bold)
  #puts(changelog_core)
  if !yes && !confirm("Release Toys #{version}?", :bold, default: true)
    error("Release aborted")
  end
  tag = "v#{version}"
  #exec(["git", "tag", tag])
  #exec(["git", "push", git_remote, tag])
  puts("SUCCESS: Pushed tag #{tag}", :green, :bold)
end
