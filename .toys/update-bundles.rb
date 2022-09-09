# frozen_string_literal: true

desc "Update bundles in both gems"

include :terminal
include :exec, exit_on_nonzero_status: true

def run
  ::Dir.chdir(context_directory)

  puts("**** Updating root bundle...", :bold, :cyan)
  exec(["bundle", "update"])

  puts("**** Updating toys-core bundle...", :bold, :cyan)
  exec(["bundle", "update"], chdir: "toys-core")

  puts("**** Updating toys bundle...", :bold, :cyan)
  exec(["bundle", "update"], chdir: "toys")
end
