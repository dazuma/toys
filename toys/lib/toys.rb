# frozen_string_literal: true

# Copyright 2019 Daniel Azuma
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
# IN THE SOFTWARE.
;

##
# Toys is a configurable command line tool. Write commands in config files
# using a simple DSL, and Toys will provide the command line binary and take
# care of all the details such as argument parsing, online help, and error
# reporting. Toys is designed for software developers, IT professionals, and
# other power users who want to write and organize scripts to automate their
# workflows. It can also be used as a Rake replacement, providing a more
# natural command line interface for your project's build tasks.
#
module Toys
  ##
  # Path to the Toys binary
  # @return [String]
  #
  BINARY_PATH = ::ENV["TOYS_BIN_PATH"] || "toys"

  ##
  # Namespace for standard template classes.
  #
  module Templates; end
end

require "toys/version"

# Add toys-core to the load path. The Toys debug scripts will set this
# environment variable explicitly, but in production, we get it from rubygems.
# We prepend to $LOAD_PATH directly rather than calling Kernel.gem, so that we
# don't get clobbered in case someone sets up bundler later.
::ENV["TOYS_CORE_LIB_PATH"] ||= begin
  dep = Gem::Dependency.new("toys-core", "= #{::Toys::VERSION}")
  dep.to_spec.full_require_paths.first
end
$LOAD_PATH.unshift(::ENV["TOYS_CORE_LIB_PATH"])

require "toys-core"
require "toys/standard_cli"
