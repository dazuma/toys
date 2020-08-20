# frozen_string_literal: true

module Toys
  module StandardMixins
    ##
    # Ensures that a bundle is installed and set up when this tool is run.
    #
    # The following parameters can be passed when including this mixin:
    #
    #  *  `:static` (Boolean) If `true`, installs the bundle immediately, when
    #     defining the tool. If `false` (the default), installs the bundle just
    #     before the tool runs.
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

      on_initialize do |static: false, search_dirs: nil, **kwargs|
        unless static
          require "toys/utils/gems"
          search_dirs = ::Toys::StandardMixins::Bundler.resolve_search_dirs(
            search_dirs,
            self[::Toys::Context::Key::CONTEXT_DIRECTORY],
            self[::Toys::Context::Key::TOOL_SOURCE]
          )
          ::Toys::StandardMixins::Bundler.setup_bundle(search_dirs, **kwargs)
        end
      end

      on_include do |static: false, search_dirs: nil, **kwargs|
        if static
          require "toys/utils/gems"
          search_dirs = ::Toys::StandardMixins::Bundler.resolve_search_dirs(
            search_dirs, context_directory, source_info
          )
          ::Toys::StandardMixins::Bundler.setup_bundle(search_dirs, **kwargs)
        end
      end

      ## @private
      def self.resolve_search_dirs(search_dirs, context_dir, source_info)
        search_dirs ||= [:toys, :context, :current]
        Array(search_dirs).flat_map do |dir|
          case dir
          when :context
            context_dir
          when :current
            ::Dir.getwd
          when :toys
            toys_dir_stack(source_info)
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
          if source_info.source_type == :directory
            dirs << [source_info.source_path, ".gems.rb", "Gemfile"]
          end
          source_info = source_info.parent
        end
        dirs
      end

      ## @private
      def self.setup_bundle(search_dirs,
                            groups: nil,
                            on_missing: nil,
                            on_conflict: nil,
                            terminal: nil,
                            input: nil,
                            output: nil)
        gems = ::Toys::Utils::Gems.new(on_missing: on_missing, on_conflict: on_conflict,
                                       terminal: terminal, input: input, output: output)
        gems.bundle(groups: groups, search_dirs: search_dirs)
      end
    end
  end
end
