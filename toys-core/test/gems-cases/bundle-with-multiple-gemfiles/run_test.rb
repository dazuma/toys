# frozen_string_literal: true

require "toys-core"
require "toys/utils/gems"

# Load the local bundle
Toys::Utils::Gems.new.bundle(search_dirs: Dir.getwd)

# Highline is in the local bundle. Make sure it is accessible.
require "highline"
