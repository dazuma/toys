# frozen_string_literal: true

desc "Update bundles in both gems"

include :terminal
include :exec, exit_on_nonzero_status: true

def run
  ::Dir.chdir(context_directory)

  puts("**** Updating root bundle...", :bold, :cyan)
  exec(["bundle", "update"])

  ["toys-core", "toys"].each do |gem_name|
    puts("**** Updating #{gem_name} bundle...", :bold, :cyan)
    ::Dir.chdir(gem_name) do
      exec(["bundle", "update"])
    end
  end
end
