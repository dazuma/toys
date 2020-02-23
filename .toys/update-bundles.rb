# frozen_string_literal: true

desc "Update bundles in both gems"

include :terminal
include :exec

def handle_gem(gem_name)
  puts("**** Updating #{gem_name} bundle...", :bold, :cyan)
  ::Dir.chdir(::File.join(context_directory, gem_name)) do
    result = exec(["bundle", "update"])
    exit(result.exit_code) unless result.success?
  end
end

def run
  handle_gem("toys-core")
  handle_gem("toys")
end
