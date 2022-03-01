# frozen_string_literal: true

require "toys-core"
require "toys/utils/gems"
require "json"

# Load the local bundle
Toys::Utils::Gems.new.bundle(search_dirs: Dir.getwd)

# Make sure we can still use JSON
::JSON.parse "{}"
