# frozen_string_literal: true

desc "Pushes docs to gh-pages from the local checkout"

flag :tmp_dir, default: "tmp"
flag :default, "--[no-]default", default: true
flag :dry_run, "--[no-]dry-run", default: true
flag :git_remote, "--git-remote=NAME", default: "origin"

include :exec, exit_on_nonzero_status: true
include :fileutils
include :terminal
include "release-tools"

def run
  cd(context_directory)
  version = capture(["./toys-dev", "system", "version"]).strip
  exit(1) unless confirm("Build and push yardocs for version #{version}? ")

  mkdir_p(tmp_dir)
  cd(tmp_dir) do
    rm_rf("toys")
    exec(["git", "clone", "git@github.com:dazuma/toys.git"])
  end
  gh_pages_dir = "#{tmp_dir}/toys"
  cd(gh_pages_dir) do
    exec(["git", "checkout", "gh-pages"])
  end

  build_docs("toys-core", version, gh_pages_dir)
  build_docs("toys", version, gh_pages_dir)
  set_default_docs(version, gh_pages_dir) if default

  push_docs(version, gh_pages_dir, live_release: !dry_run, git_remote: git_remote)
end
