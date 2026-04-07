# frozen_string_literal: true

require "toys-core"
require "toys/utils/gems"

# Activate a gem
result = Toys::Utils::Gems.new.activate("highline", "= 2.0.1")
result2 = Toys::Utils::Gems.new.activate("highline", "= 2.0.1")
puts "result: #{result.inspect}"
puts "result2: #{result2.inspect}"

# Make sure it is accessible.
require "highline"
