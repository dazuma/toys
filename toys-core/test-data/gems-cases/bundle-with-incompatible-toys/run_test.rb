# frozen_string_literal: true

require "toys-core"
require "toys/utils/gems"

# Load the local bundle
begin
  Toys::Utils::Gems.new.bundle(search_dirs: Dir.getwd)
ensure
  puts "Unexpected BUNDLE_GEMFILE: #{ENV['BUNDLE_GEMFILE']}" if ENV["BUNDLE_GEMFILE"]
end

# Shouldn't get here
puts "should-not-get-here"
