# frozen_string_literal: true

##
# Toys is a configurable command line tool. Write commands in config files
# using a simple DSL, and Toys will provide the command line executable and
# take care of all the details such as argument parsing, online help, and error
# reporting. Toys is designed for software developers, IT professionals, and
# other power users who want to write and organize scripts to automate their
# workflows. It can also be used as a Rake replacement, providing a more
# natural command line interface for your project's build tasks.
#
module Toys
  ##
  # The Toys Release system is a set of conventional commits based release
  # tools, distributed in a Rubygem. The functionality is not available via
  # Ruby libraries. Instead use the Toys load_gem functionality to import the
  # release tools into your project. See the readme and user guide for details.
  #
  module Release
  end
end

require "toys/release/version"
