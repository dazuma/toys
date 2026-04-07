# frozen_string_literal: true

require "toys-core"
require "toys/utils/gems"

# Load the local bundle
result = Toys::Utils::Gems.new.bundle(search_dirs: Dir.getwd)
puts "result: #{result.inspect}"

# Highline is in the local bundle. Make sure it is accessible.
require "highline"

# Make sure toys-core is still accessible.
require "toys/utils/help_text"

# Make sure the BUNDLE_GEMFILE is correct
unless ENV["BUNDLE_GEMFILE"] == File.join(__dir__, "Gemfile")
  raise "Incorrect BUNDLE_GEMFILE: #{ENV['BUNDLE_GEMFILE']}"
end

# Make sure supports_suggestions doesn't crash
Toys::Compat.supports_suggestions?
