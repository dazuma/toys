# frozen_string_literal: true

desc "Update bundles in both gems"

include :terminal
include :exec, exit_on_nonzero_status: true

def handle_gem(gem_name)
  puts("**** Updating #{gem_name} bundle...", :bold, :cyan)
  ::Dir.chdir(::File.join(context_directory, gem_name)) do
    exec(["bundle", "update"])
  end
end

def run
  handle_gem("toys-core")
  handle_gem("toys")
end
