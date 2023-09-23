# frozen_string_literal: true

module Toys
  module StandardMixins
    ##
    # Ensures that a bundle is installed and set up when this tool is run.
    #
    # This is the normal recommended way to use [bundler](https://bundler.io)
    # with Toys. Including this mixin in a tool will cause Toys to ensure that
    # the bundle is installed and available during tool execution. For example:
    #
    #     tool "run-rails" do
    #       include :bundler
    #       def run
    #         # Note: no "bundle exec" required because Toys has already
    #         # installed and loaded the bundle.
    #         exec "rails s"
    #       end
    #     end
    #
    # ### Customization
    #
    # The following parameters can be passed when including this mixin:
    #
    #  *  `:static` (Boolean) If `true`, installs the bundle immediately, when
    #     defining the tool. If `false` (the default), installs the bundle just
    #     before the tool runs.
    #
    #  *  `:groups` (Array\<String\>) The groups to include in setup.
    #
    #  *  `:gemfile_path` (String) The path to the Gemfile to use. If `nil` or
    #     not given, the `:search_dirs` will be searched for a Gemfile.
    #
    #  *  `:search_dirs` (String,Symbol,Array\<String,Symbol\>) Directories to
    #     search for a Gemfile.
    #
    #     You can pass full directory paths, and/or any of the following:
    #      *  `:context` - the current context directory.
    #      *  `:current` - the current working directory.
    #      *  `:toys` - the Toys directory containing the tool definition, and
    #         any of its parents within the Toys directory hierarchy.
    #
    #     The default is to search `[:toys, :context, :current]` in that order.
    #     See {DEFAULT_SEARCH_DIRS}.
    #
    #     For most directories, the bundler mixin will look for the files
    #     ".gems.rb", "gems.rb", and "Gemfile", in that order. In `:toys`
    #     directories, it will look only for ".gems.rb" and "Gemfile", in that
    #     order. These can be overridden by setting the `:gemfile_names` and/or
    #     `:toys_gemfile_names` arguments.
    #
    #  *  `:gemfile_names` (Array\<String\>) File names that are recognized as
    #     Gemfiles when searching in directories other than Toys directories.
    #     Defaults to {Toys::Utils::Gems::DEFAULT_GEMFILE_NAMES}.
    #
    #  *  `:toys_gemfile_names` (Array\<String\>) File names that are
    #     recognized as Gemfiles when searching in Toys directories.
    #     Defaults to {DEFAULT_TOYS_GEMFILE_NAMES}.
    #
    #  *  `:on_missing` (Symbol) What to do if a needed gem is not installed.
    #
    #     Supported values:
    #      *  `:confirm` - prompt the user on whether to install (default).
    #      *  `:error` - raise an exception.
    #      *  `:install` - just install the gem.
    #
    #  *  `:on_conflict` (Symbol) What to do if bundler has already been run
    #     with a different Gemfile.
    #
    #     Supported values:
    #      *  `:error` - raise an exception (default).
    #      *  `:ignore` - just silently proceed without bundling again.
    #      *  `:warn` - print a warning and proceed without bundling again.
    #
    #  *  `:retries` (Integer) Number of times to retry bundler operations
    #     (optional)
    #
    #  *  `:terminal` (Toys::Utils::Terminal) Terminal to use (optional)
    #  *  `:input` (IO) Input IO (optional, defaults to STDIN)
    #  *  `:output` (IO) Output IO (optional, defaults to STDOUT)
    #
    module Bundler
      include Mixin

      ##
      # Default search directories for Gemfiles.
      # @return [Array<String,Symbol>]
      #
      DEFAULT_SEARCH_DIRS = [:toys, :context, :current].freeze

      ##
      # The gemfile names that are searched by default in Toys directories.
      # @return [Array<String>]
      #
      DEFAULT_TOYS_GEMFILE_NAMES = [".gems.rb", "Gemfile"].freeze

      ##
      # @private
      #
      def self.setup_bundle(context_directory,
                            source_info,
                            gemfile_path: nil,
                            search_dirs: nil,
                            gemfile_names: nil,
                            toys_gemfile_names: nil,
                            groups: nil,
                            on_missing: nil,
                            on_conflict: nil,
                            retries: nil,
                            terminal: nil,
                            input: nil,
                            output: nil)
        require "toys/utils/gems"
        gemfile_path ||= begin
          gemfile_finder = GemfileFinder.new(context_directory, source_info,
                                             gemfile_names, toys_gemfile_names)
          gemfile_finder.search(search_dirs || DEFAULT_SEARCH_DIRS)
        end
        gems = ::Toys::Utils::Gems.new(on_missing: on_missing, on_conflict: on_conflict,
                                       terminal: terminal, input: input, output: output)
        gems.bundle(groups: groups, gemfile_path: gemfile_path, retries: retries)
      end

      on_initialize do |static: false, **kwargs|
        unless static
          context_directory = self[::Toys::Context::Key::CONTEXT_DIRECTORY]
          source_info = self[::Toys::Context::Key::TOOL_SOURCE]
          ::Toys::StandardMixins::Bundler.setup_bundle(context_directory, source_info, **kwargs)
        end
      end

      on_include do |static: false, **kwargs|
        if static
          ::Toys::StandardMixins::Bundler.setup_bundle(context_directory, source_info, **kwargs)
        end
      end

      ##
      # @private
      #
      class GemfileFinder
        ##
        # @private
        #
        def initialize(context_directory, source_info, gemfile_names, toys_gemfile_names)
          @context_directory = context_directory
          @source_info = source_info
          @gemfile_names = gemfile_names
          @toys_gemfile_names = toys_gemfile_names || DEFAULT_TOYS_GEMFILE_NAMES
        end

        ##
        # @private
        #
        def search(search_dir)
          case search_dir
          when ::Array
            search_array(search_dir)
          when ::String
            ::Toys::Utils::Gems.find_gemfile(search_dir, gemfile_names: @gemfile_names)
          when :context
            search(@context_directory)
          when :current
            search(::Dir.getwd)
          when :toys
            search_toys
          else
            raise ::ArgumentError, "Unrecognized search_dir: #{dir.inspect}"
          end
        end

        private

        def search_array(search_dirs)
          search_dirs.each do |search_dir|
            result = search(search_dir)
            return result if result
          end
          nil
        end

        def search_toys
          source_info = @source_info
          while source_info
            if source_info.source_type == :directory &&
               source_info.source_path != source_info.context_directory
              result = ::Toys::Utils::Gems.find_gemfile(source_info.source_path,
                                                        gemfile_names: @toys_gemfile_names)
              return result if result
            end
            source_info = source_info.parent
          end
          nil
        end
      end
    end
  end
end
