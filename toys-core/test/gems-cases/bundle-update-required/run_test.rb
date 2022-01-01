# frozen_string_literal: true

puts "***"
require "toys-core"
require "toys/utils/gems"
puts "*****"

# Load the local bundle
Toys::Utils::Gems.new.bundle(search_dirs: Dir.getwd)
puts "**********"
