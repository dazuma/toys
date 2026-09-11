# frozen_string_literal: true

require "toys-core"
require "toys/utils/gems"

# Activate a gem
result = Toys::Utils::Gems.new(default_confirm: false).activate("highline", "= 2.0.1")
puts "result: #{result.inspect}"

# Make sure it is accessible.
require "highline"
