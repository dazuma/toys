# frozen_string_literal: true

require "toys/version"

# Add toys-core to the load path. The Toys debug scripts will set this
# environment variable explicitly, but in production, we get it from rubygems.
# We prepend to $LOAD_PATH directly rather than calling Kernel.gem, so that we
# don't get clobbered in case someone sets up bundler later.
unless ::ENV.key?("TOYS_CORE_LIB_PATH")
  path = ::File.expand_path("../../toys-core-#{::Toys::VERSION}/lib", __dir__)
  unless path && ::File.directory?(path)
    require "rubygems"
    dep = ::Gem::Dependency.new("toys-core", "= #{::Toys::VERSION}")
    path = dep.to_spec.full_require_paths.first
  end
  abort "Unable to find toys-core gem!" unless path && ::File.directory?(path)
  ::ENV.store("TOYS_CORE_LIB_PATH", path)
end

$LOAD_PATH.delete(::ENV["TOYS_CORE_LIB_PATH"])
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
# This set of documentation includes classes from both Toys-Core, the
# underlying command line framework, and the Toys executable itself. Most of
# the actual classes you will likely need to look up are from Toys-Core.
#
# ## Common starting points
#
# * For information on the DSL used to write tools, start with
#   {Toys::DSL::Tool}.
# * The base class for tool runtime (i.e. that defines the basic methods
#   available to a tool's implementation) is {Toys::Context}.
# * For information on writing mixins, see {Toys::Mixin}.
# * For information on writing templates, see {Toys::Template}.
# * For information on writing acceptors, see {Toys::Acceptor}.
# * For information on writing custom shell completions, see {Toys::Completion}.
# * Standard mixins are defined under the {Toys::StandardMixins} module.
# * Various utilities are defined under {Toys::Utils}. Some of these serve as
#   the implementations of corresponding mixins.
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
  # @private
  #
  LIB_PATH = __dir__

  ##
  # Namespace for standard template classes.
  #
  # These templates are provided by Toys and can be expanded by name by passing
  # a symbol to {Toys::DSL::Tool#expand}.
  #
  module Templates; end
end

::Toys.executable_path = ::Toys::EXECUTABLE_PATH

require "toys/standard_cli"
