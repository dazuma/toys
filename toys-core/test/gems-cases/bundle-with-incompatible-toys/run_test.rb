# frozen_string_literal: true

require "toys-core"
require "toys/utils/gems"

# Load the local bundle
Toys::Utils::Gems.new.bundle(search_dirs: Dir.getwd)

# Shouldn't get here
puts "should-not-get-here"
