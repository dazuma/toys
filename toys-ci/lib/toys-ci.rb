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
  # The Toys CI system is a mixin and template useful for generating CI tools.
  #
  # In this system, a CI tool is a tool that calls some set of other tools or
  # processes, each of which implements an individual job such as doing a build
  # or running tests. The CI tool monitors and summarizes the results of those
  # jobs.
  #
  # See {Toys::CI::Mixin} for a lower-level mixin that provides useful methods
  # for implementing a CI tool, including methods for finding changed files,
  # for running individual jobs, and for reporting results.
  #
  # See {Toys::CI::Template} for a higher-level template that generates a full
  # CI tool, including flags for controlling how CI should behave and which
  # jobs should be run.
  #
  module CI
  end
end

require "toys/ci/mixin"
require "toys/ci/template"
require "toys/ci/version"
