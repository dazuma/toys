# frozen_string_literal: true

module Toys
  module Templates
    ##
    # A template for tools that clean build artifacts
    #
    class Clean
      include Template

      ##
      # Default tool name
      # @return [String]
      #
      DEFAULT_TOOL_NAME = "clean"

      ##
      # Create the template settings for the Clean template.
      #
      # @param name [String] Name of the tool to create. Defaults to
      #     {DEFAULT_TOOL_NAME}.
      # @param paths [Array<String,:gitignore>] An array of glob patterns
      #     indicating what to clean. You can also include the symbol
      #     `:gitignore` which will clean all items covered by `.gitignore`
      #     files, if contained in a git working tree.
      # @param preserve [Array<String>] An array of glob patterns indicating
      #     what to preserve. Matching paths will be skipped even if they
      #     match `paths`.
      # @param context_directory [String] A custom context directory to use
      #     when executing this tool.
      #
      def initialize(name: nil, paths: [], preserve: [], context_directory: nil)
        @name = name
        @paths = paths
        @preserve = preserve
        @context_directory = context_directory
      end

      ##
      # Name of the tool to create.
      #
      # @param value [String]
      # @return [String]
      #
      attr_writer :name

      ##
      # An array of glob patterns indicating what to clean. May also include
      # the symbol `:gitignore` which indicates all items covered by
      # `.gitignore` files, if contained in a git working tree.
      #
      # @param value [Array<String,:gitignore>]
      # @return [Array<String,:gitignore>]
      #
      attr_writer :paths

      ##
      # An array of glob patterns indicating what to preserve.
      #
      # @param value [Array<String>]
      # @return [Array<String>]
      #
      attr_writer :preserve

      ##
      # Custom context directory for this tool.
      #
      # @param value [String]
      # @return [String]
      #
      attr_writer :context_directory

      ##
      # @private
      #
      attr_reader :context_directory

      ##
      # @private
      #
      def paths
        Array(@paths)
      end

      ##
      # @private
      #
      def preserve
        Array(@preserve)
      end

      ##
      # @private
      #
      def name
        @name || DEFAULT_TOOL_NAME
      end

      on_expand do |template|
        tool(template.name) do
          desc "Clean built files and directories."

          flag(:dry_run, "--dry-run", "-n") do
            desc "Dry run that outputs files that would be cleaned but doesn't actually delete them"
          end

          set_context_directory template.context_directory if template.context_directory

          paths = template.paths.dup
          static :template_gitignore, paths.delete(:gitignore)

          paths.each do |elem|
            unless elem.is_a?(::String)
              raise Toys::ToolDefinitionError,
                    "Unexpected element in paths: #{elem.inspect} (expected a glob or :gitignore)"
            end
          end
          static :template_paths, paths

          template.preserve.each do |elem|
            unless elem.is_a?(::String)
              raise Toys::ToolDefinitionError, "Unexpected element in preserve: #{elem.inspect} (expected a glob)"
            end
          end
          static :template_preserve, template.preserve

          include :fileutils
          include :exec

          ##
          # @private
          #
          def run
            cd(context_directory || ::Dir.getwd) do
              preserve_set = make_preserve_set(template_preserve)
              clean_globs(template_paths, preserve_set)
              clean_gitignore(preserve_set) if template_gitignore
            end
          end

          ##
          # @private
          # Takes a possibly empty array of globs. For each, adds matching
          # paths to the set of paths to preserve. Returns the set. All parent
          # and ancestor directories are also included in the set. This
          # prevents the cleaner from deleting those directories recursively
          # since there are preserved contents.
          #
          def make_preserve_set(globs)
            require "set"
            preserve_set = ::Set.new << "."
            process_globs(globs) do |path|
              until preserve_set.include?(path)
                preserve_set << path
                path = File.dirname(path)
              end
            end
            preserve_set
          end

          ##
          # @private
          # Takes a possibly empty array of globs. For each, attempts to clean
          # matching paths that are not included in the given preserve set.
          #
          def clean_globs(globs, preserve_set)
            process_globs(globs) do |path|
              unless preserve_set.include?(path)
                rm_rf(path) unless dry_run
                puts "Cleaned: #{path}"
              end
            end
          end

          ##
          # @private
          # Iterates through the entire directory structure recursively. Cleans
          # anything that is not covered in the given preserve set AND is
          # covered by gitignore.
          #
          def clean_gitignore(preserve_set)
            result = exec(["git", "rev-parse", "--is-inside-work-tree"], out: :null, err: :null)
            unless result.success?
              logger.error("Skipping :gitignore because we don't seem to be in a git directory")
              return
            end
            exec(["git", "check-ignore", "--stdin"], in: :controller, out: :controller) do |controller|
              ::Thread.new do
                ::Dir.children(".").sort.each do |child|
                  process_path(child) do |path|
                    controller.in.puts(path) unless preserve_set.include?(path)
                  end
                end
              ensure
                controller.in.close
              end
              controller.out.each_line do |path|
                path = path.chomp
                rm_rf(path) unless dry_run
                puts "Cleaned: #{path}"
              end
            end
          end

          ##
          # @private
          # Iterates through a list of globs. For each glob, iterates over all
          # matching paths and calls the given block.
          #
          def process_globs(globs, &block)
            globs.each do |glob|
              ::Dir.glob(glob) do |path|
                process_path(path.sub(%r{/$}, ""), &block)
              end
            end
          end

          ##
          # @private
          # For the given path and all its recursive descendents, calls the
          # given block. Calls the block on children before parents.
          #
          def process_path(path, &block)
            begin
              children = ::File.lstat(path).directory? ? ::Dir.children(path).sort : []
            rescue ::Errno::ENOENT, ::Errno::ENOTDIR
              # Something happened to the path. Just skip it.
              return
            end
            children.each do |child|
              process_path(::File.join(path, child), &block)
            end
            yield path
          end
        end
      end
    end
  end
end
