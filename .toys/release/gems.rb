# frozen_string_literal: true

desc "Builds and releases both gems from the local checkout"

required_arg :version
flag :dry_run, "--[no-]dry-run", default: false

include :exec, exit_on_nonzero_status: true
include :terminal
include "release-tools"

def run
  ::Dir.chdir(context_directory)

  verify_git_clean(warn_only: true)
  verify_library_versions(version, warn_only: true)
  verify_changelog_content("toys-core", version, warn_only: true)
  verify_changelog_content("toys", version, warn_only: true)
  verify_github_checks(warn_only: true)

  unless confirm("Build and push gems for version #{version}? ", :bold)
    error("Release aborted")
  end

  build_gem("toys-core", version)
  build_gem("toys", version)

  push_gem("toys-core", version, dry_run: dry_run)
  push_gem("toys", version, dry_run: dry_run)
end
