# frozen_string_literal: true

desc "Builds and releases both gems from the local checkout"

flag :dry_run, "--[no-]dry-run", default: true

include :exec, exit_on_nonzero_status: true
include :terminal
include "release-tools"

def run
  ::Dir.chdir(context_directory)
  version = capture(["./toys-dev", "system", "version"]).strip
  exit(1) unless confirm("Build and push gems for version #{version}? ")

  build_gem("toys-core", version)
  build_gem("toys", version)

  push_gem("toys-core", version, live_release: !dry_run)
  push_gem("toys", version, live_release: !dry_run)
end
