# frozen_string_literal: true

require "toys-core"
require "toys/utils/gems"

# Activate a gem without requiring it, the way toys activates its own
# dependencies. Bundler strips such a gem from the load path unless the bundle
# sets it up, so this is the case that a group filter can break.
gem("abbrev")
abbrev_path = Gem.loaded_specs["abbrev"].full_gem_path
raise "abbrev should not be required yet" if $LOADED_FEATURES.any? { |f| f.start_with?(abbrev_path) }

# Ask for a group set that does not include :default. "abbrev" is declared
# outside any group, so only the pinning group keeps it in scope.
result = Toys::Utils::Gems.new.bundle(search_dirs: Dir.getwd, groups: ["development"])
puts "result: #{result.inspect}"

# The requested group was set up.
require "highline"

# And so was the gem toys had already loaded, despite being outside that group.
require "abbrev"
puts "abbrev: loaded"
