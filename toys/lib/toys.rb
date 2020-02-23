# frozen_string_literal: true

require "toys/version"

# Add toys-core to the load path. The Toys debug scripts will set this
# environment variable explicitly, but in production, we get it from rubygems.
# We prepend to $LOAD_PATH directly rather than calling Kernel.gem, so that we
# don't get clobbered in case someone sets up bundler later.
::ENV["TOYS_CORE_LIB_PATH"] ||= begin
  path = ::File.expand_path("../../toys-core-#{::Toys::VERSION}/lib", __dir__)
  unless path && ::File.directory?(path)
    require "rubygems"
    dep = ::Gem::Dependency.new("toys-core", "= #{::Toys::VERSION}")
    path = dep.to_spec.full_require_paths.first
  end
  abort "Unable to find toys-core gem!" unless path && ::File.directory?(path)
  path
end
$LOAD_PATH.unshift(::ENV["TOYS_CORE_LIB_PATH"])

require "toys-core"

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
  # Path to the Toys executable.
  #
  # @return [String] Absolute path to the executable
  # @return [nil] if the Toys executable is not running.
  #
  EXECUTABLE_PATH = ::ENV["TOYS_BIN_PATH"]

  ##
  # Namespace for standard template classes.
  #
  module Templates; end
end

::Toys.executable_path = ::Toys::EXECUTABLE_PATH

require "toys/standard_cli"
