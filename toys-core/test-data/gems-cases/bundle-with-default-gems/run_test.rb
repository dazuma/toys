# frozen_string_literal: true

require "toys-core"
require "toys/utils/gems"
require "json"

# Load the local bundle
result = Toys::Utils::Gems.new.bundle(search_dirs: Dir.getwd)
puts "result: #{result.inspect}"

# Make sure we can still use JSON
::JSON.parse "{}"
