# frozen_string_literal: true

require "toys-core"
require "toys/utils/gems"

# Load the local bundle
result = Toys::Utils::Gems.new.bundle(search_dirs: Dir.getwd)
result2 = Toys::Utils::Gems.new.bundle(search_dirs: Dir.getwd)
puts "result: #{result.inspect}"
puts "result2: #{result2.inspect}"
