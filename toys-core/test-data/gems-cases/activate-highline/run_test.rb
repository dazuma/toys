# frozen_string_literal: true

require "toys-core"
require "toys/utils/gems"

# Activate a gem
Toys::Utils::Gems.new.activate("highline", "= 2.0.1")

# Make sure it is accessible.
require "highline"
