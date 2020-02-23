# frozen_string_literal: true

module Toys
  module StandardMixins
    ##
    # Ensures that a bundle is installed and set up when this tool is run.
    #
    # The following parameters can be passed when including this mixin:
    #
    #  *  `:groups` (Array<String>) The groups to include in setup
    #
    #  *  `:search_dirs` (Array<String,Symbol>) Directories to search for a
    #     Gemfile.
    #
    #     You can pass full directory paths, and/or any of the following:
    #      *  `:context` - the current context directory
    #      *  `:current` - the current working directory
    #      *  `:toys` - the Toys directory containing the tool definition
    #
    #     The default is to search `[:toys, :context, :current]` in that order.
    #
    #  *  `:on_missing` (Symbol) What to do if a needed gem is not installed.
    #
    #     Supported values:
    #      *  `:confirm` - prompt the user on whether to install (default)
    #      *  `:error` - raise an exception
    #      *  `:install` - just install the gem
    #
    #  *  `:on_conflict` (Symbol) What to do if bundler has already been run
    #     with a different Gemfile.
    #
    #     Supported values:
    #      *  `:error` - raise an exception (default)
    #      *  `:ignore` - just silently proceed without bundling again
    #      *  `:warn` - print a warning and proceed without bundling again
    #
    #  *  `:terminal` (Toys::Utils::Terminal) Terminal to use (optional)
    #  *  `:input` (IO) Input IO (optional, defaults to STDIN)
    #  *  `:output` (IO) Output IO (optional, defaults to STDOUT)
    #
    module Bundler
      include Mixin

      on_initialize do
        |groups: nil,
         search_dirs: nil,
         on_missing: nil,
         on_conflict: nil,
         terminal: nil,
         input: nil,
         output: nil|
        require "toys/utils/gems"
        search_dirs = ::Toys::StandardMixins::Bundler.resolve_search_dirs(search_dirs, self)
        gems = ::Toys::Utils::Gems.new(on_missing: on_missing, on_conflict: on_conflict,
                                       terminal: terminal, input: input, output: output)
        gems.bundle(groups: groups, search_dirs: search_dirs)
      end

      ## @private
      def self.resolve_search_dirs(search_dirs, context)
        search_dirs ||= [:toys, :context, :current]
        Array(search_dirs).flat_map do |dir|
          case dir
          when :context
            context[::Toys::Context::Key::CONTEXT_DIRECTORY]
          when :current
            ::Dir.getwd
          when :toys
            toys_dir_stack(context[::Toys::Context::Key::TOOL_SOURCE])
          when ::String
            dir
          else
            raise ::ArgumentError, "Unrecognized search_dir: #{dir.inspect}"
          end
        end
      end

      ## @private
      def self.toys_dir_stack(source_info)
        dirs = []
        while source_info
          dirs << source_info.source_path if source_info.source_type == :directory
          source_info = source_info.parent
        end
        dirs
      end
    end
  end
end
