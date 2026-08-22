# frozen_string_literal: true

##
# Toys is a configurable command line tool. Write commands in source files
# using a simple DSL, and Toys will provide the command line executable and
# take care of all the details such as argument parsing, online help, and error
# reporting. Toys is designed for software developers, IT professionals, and
# other power users who want to write and organize scripts to automate their
# workflows. It can also be used as a Rake replacement, providing a more
# natural command line interface for your project's build tasks.
#
# This module contains the command line framework underlying Toys. It can be
# used to create command line executables using the Toys DSL and classes.
#
# ## Common starting points
#
# Some of the most commonly needed class documentation is listed below:
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
# * The main entrypoint for the command line framework is {Toys::CLI}.
#
# ## Architecture layers
#
# The classes directly under the {Toys} module are not grouped by directory,
# but fall into four layers, listed here from the outside in. Except where
# noted below, dependencies point downward.
#
# * **Execution** — runs tools. {Toys::CLI} is the main entrypoint and owns
#   the configuration, {Toys::Runner} holds the environment tools run in and
#   carries out each run, {Toys::ArgParser} parses the command line, and
#   {Toys::Context} is the base class for tool runtime.
# * **Loading** — resolves a tool name to a definition. {Toys::Loader}
#   discovers and loads Toys files, {Toys::SourceInfo} tracks their
#   provenance, and {Toys::InputFile} evaluates them. A source is described
#   unresolved by a {Toys::SourceSpec}; {Toys::SourceList} is the ordered
#   collection of root sources that a loader reads tools from, and assigns
#   each a priority. The loader resolves each spec into a {Toys::SourceInfo}
#   when it first needs that priority level. Note that {Toys::Loader} is the
#   factory for Definition objects (described below) and thus holds onto
#   several objects that are necessary for constructing tool definitions.
# * **Definition** — models a tool. {Toys::ToolDefinition} is the central
#   class, with {Toys::Flag}, {Toys::FlagGroup}, and {Toys::PositionalArg} as
#   its components, along with the pluggable {Toys::Acceptor} and
#   {Toys::Completion} types that the DSL attaches to flags and args.
# * **Support** — shared vocabulary used by all of the above. This includes
#   the pluggable extension types {Toys::Mixin}, {Toys::Template}, and
#   {Toys::Middleware}, which are resolved by name through
#   {Toys::ModuleLookup}, as well as {Toys::WrappableString},
#   {Toys::ToolNameSplitter} which interprets delimiters in tool names, the
#   named sentinel {Toys::UniqueKey}, and the error classes.
#
# The deliberate upward dependencies are:
#
# * The definition layer builds each tool class as a subclass of
#   {Toys::Context}, so that a tool's implementation inherits the runtime
#   methods defined there.
# * Completion is computed against a partially parsed command line, so the
#   completion classes in the definition layer reach upward for the machinery
#   to do it. {Toys::Completion::Context} holds a {Toys::Loader} and builds a
#   {Toys::ArgParser}, and a tool's default completion uses that loader to
#   enumerate subtools and to resolve delegation targets.
# * {Toys::ToolDefinition} retains the {Toys::SourceInfo} describing where it
#   was defined.
# * The context key constants under {Toys::Context::Key}, which are
#   {Toys::UniqueKey} instances, act as shared vocabulary, and are referenced
#   from any layer.
#
module Toys
  ##
  # Namespace for DSL classes. These classes provide the directives that can be
  # used in tool files.
  #
  # DSL directives that can appear at the top level of Toys files and tool
  # blocks are defined by the {Toys::DSL::Tool} module.
  #
  # Directives that can appear within a block passed to {Toys::DSL::Tool#flag}
  # are defined by the {Toys::DSL::Flag} class.
  #
  # Directives that can appear within a {Toys::DSL::Tool#flag_group} block or
  # any of its related directives, are defined by the {Toys::DSL::FlagGroup}
  # class.
  #
  # Directives that can appear within a {Toys::DSL::Tool#required_arg},
  # {Toys::DSL::Tool#optional_arg}, or {Toys::DSL::Tool#remaining_args} block,
  # are defined by the {Toys::DSL::PositionalArg} class.
  #
  module DSL
  end

  ##
  # Namespace for standard middleware classes.
  #
  # These middleware are provided by Toys-Core and can be referenced by name
  # when creating a {Toys::CLI}.
  #
  module StandardMiddleware
    ##
    # @private
    #
    COMMON_FLAG_GROUP = :__common

    ##
    # @private
    #
    def self.append_common_flag_group(tool)
      tool.add_flag_group(type: :optional, name: COMMON_FLAG_GROUP,
                          desc: "Common Flags", report_collisions: false)
      COMMON_FLAG_GROUP
    end
  end

  ##
  # Namespace for standard mixin classes.
  #
  # These mixins are provided by Toys-Core and can be included by name by
  # passing a symbol to {Toys::DSL::Tool#include}.
  #
  module StandardMixins
  end

  ##
  # Namespace for common utility classes.
  #
  # These classes are not loaded by default, and must be required explicitly.
  # For example, before using {Toys::Utils::Exec}, you must:
  #
  #     require "toys/utils/exec"
  #
  module Utils
  end

  class << self
    ##
    # Path to the executable. This can, for example, be invoked to run a subtool
    # in a clean environment.
    #
    # @return [String] if there is an executable
    # @return [nil] if there is no such executable
    #
    attr_accessor :executable_path
  end

  ##
  # @private
  #
  CORE_LIB_PATH = __dir__
end

require "toys/compat"
require "toys/unique_key"

require "toys/acceptor"
require "toys/arg_parser"
require "toys/cli"
require "toys/completion"
require "toys/context"
require "toys/core"
require "toys/dsl/base"
require "toys/dsl/flag"
require "toys/dsl/flag_group"
require "toys/dsl/internal"
require "toys/dsl/positional_arg"
require "toys/dsl/tool"
require "toys/errors"
require "toys/flag"
require "toys/flag_group"
require "toys/input_file"
require "toys/loader"
require "toys/middleware"
require "toys/mixin"
require "toys/module_lookup"
require "toys/positional_arg"
require "toys/runner"
require "toys/source_info"
require "toys/source_list"
require "toys/source_spec"
require "toys/template"
require "toys/tool_definition"
require "toys/tool_name_splitter"
require "toys/wrappable_string"
