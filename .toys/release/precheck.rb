# frozen_string_literal: true

desc "Run release prechecks for Toys"

include :terminal
include "release-tools"

required_arg :version

def run
  ::Dir.chdir(context_directory)

  puts("Running prechecks for releasing version #{version}...", :bold)
  verify_git_clean
  verify_library_versions(version)
  verify_changelog_content("toys-core", version)
  verify_changelog_content("toys", version)
  verify_github_checks

  puts("SUCCESS", :green, :bold)
end
