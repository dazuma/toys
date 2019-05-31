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
# Toys is a Ruby library and command line tool that lets you build your own
# command line suite of tools (with commands and subcommands) using a Ruby DSL.
# You can define commands globally or configure special commands scoped to
# individual directories.
#
module Toys
  ##
  # Namespace for object definition classes.
  #
  module Definition; end

  ##
  # Namespace for DSL classes. These classes provide the directives that can be
  # used in configuration files. Most are defined in {Toys::DSL::Tool}.
  #
  module DSL; end

  ##
  # Namespace for standard mixin classes.
  #
  module StandardMixins; end

  ##
  # Namespace for common utility classes.
  #
  # These classes are not loaded by default, and must be required explicitly.
  # For example, before using {Toys::Utils::Exec}, you must
  # `require "toys/utils/exec"`.
  #
  module Utils; end
end

require "toys/arg_parser"
require "toys/cli"
require "toys/core_version"
require "toys/definition/arg"
require "toys/definition/flag"
require "toys/definition/flag_group"
require "toys/dsl/arg"
require "toys/dsl/flag"
require "toys/dsl/flag_group"
require "toys/dsl/tool"
require "toys/acceptor"
require "toys/alias_definition"
require "toys/completion"
require "toys/errors"
require "toys/input_file"
require "toys/loader"
require "toys/middleware"
require "toys/mixin"
require "toys/module_lookup"
require "toys/runner"
require "toys/source_info"
require "toys/standard_middleware"
require "toys/template"
require "toys/tool"
require "toys/tool_definition"
require "toys/wrappable_string"
