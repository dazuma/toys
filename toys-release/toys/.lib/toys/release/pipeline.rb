# frozen_string_literal: true

require "fileutils"

module Toys
  module Release
    ##
    # The pipeline context
    #
    class Pipeline
      ##
      # Internal exception signaling that the step should end immediately but
      # the pipeline should continue.
      # @private
      #
      class StepExit < ::StandardError
      end

      ##
      # Internal exception signaling that the step should end immediately and
      # the pipeline should be aborted.
      # @private
      #
      class PipelineExit < ::StandardError
      end

      ##
      # Context provided to a step implementation
      #
      class StepContext
        # @private
        def initialize(pipeline, step_settings)
          @pipeline = pipeline
          @step_settings = step_settings
          type_name = step_settings.type
          type_name = type_name.upcase unless type_name =~ /^[A-Z]/
          @step_impl = begin
            ::Toys::Release::Steps.const_get(type_name)
          rescue ::NameError
            pipeline.repository.utils.error("Unknown step type: #{type_name}")
          end
          @step_impl = @step_impl.new if @step_impl.is_a?(::Class)
          @will_run = false
        end

        ##
        # @return [boolean] Whether this step has been marked as will_run
        #
        def will_run?
          @will_run
        end

        ##
        # @return [boolean] Whether this step is explicitly requested in config
        #
        def requested?
          @step_settings.requested?
        end

        ##
        # @return [String] The step name
        #
        def name
          @step_settings.name
        end

        ##
        # @return [Array<Toys::Release::InputSettings>] The input settings
        #
        def input_settings
          @step_settings.inputs
        end

        ##
        # @return [Array<Toys::Release::OutputSettings>] The output settings
        #
        def output_settings
          @step_settings.outputs
        end

        ##
        # @return [Toys::Release::EnvironmentUtils] Environment utils
        #
        def utils
          @pipeline.utils
        end

        ##
        # @return [Toys::Release::Repository] The repository
        #
        def repository
          @pipeline.repository
        end

        ##
        # @return [Toys::Release::Component] Component being released
        #
        def component
          @pipeline.component
        end

        ##
        # @return [::Gem::Version] Version being released
        #
        def release_version
          @pipeline.release_version
        end

        ##
        # @return [String] The name of the git remote
        #
        def git_remote
          @pipeline.git_remote
        end

        ##
        # @return [boolean] Whether this is running in dry run mode
        #
        def dry_run?
          @pipeline.dry_run
        end

        ##
        # @return [String] Short description of the release, including the
        #     component name and version
        #
        def release_description
          "#{component.name} #{release_version}"
        end

        ##
        # @return [String] Name of the gem package for this release
        #
        def gem_package_name
          "#{component.name}-#{release_version}.gem"
        end

        ##
        # @return [String] Name of the git tag
        #
        def tag_name
          "#{component.name}/v#{release_version}"
        end

        ##
        # Log a message
        #
        # @param message [String] Message to log
        #
        def log(message)
          @pipeline.utils.log(message)
        end

        ##
        # Log a warning
        #
        # @param message [String] Message to log
        #
        def warning(message)
          @pipeline.utils.warning(message)
        end

        ##
        # Add a message to the successes list
        #
        # @param message [String] Success to report
        #
        def add_success(message)
          @pipeline.performer_result.successes << message
        end

        ##
        # Exit the step immediately, but does not abort the pipeline.
        # If an error message is given, it is added to the error stream.
        #
        # @param error_message [String] Optional error message
        #
        def exit_step(error_message = nil)
          utils.error(error_message) if error_message
          raise StepExit, error_message
        end

        ##
        # Exit the step immediately, and abort the pipeline.
        # The error message is added to the error stream.
        #
        # @param error_message [String] Required error message
        #
        def abort_pipeline(error_message)
          utils.error(error_message)
          raise PipelineExit, error_message
        end

        ##
        # Get the option with the given key.
        #
        # @param key [String] Option name to fetch
        # @param required [boolean] Whether to exit with an error if the option
        #     is not set. Defaults to false, which instead returns the default.
        # @param default [Object] Default value to return if the option is not
        #     set and required is set to false.
        #
        # @return [Object] The option value
        #
        def option(key, required: false, default: nil)
          return @step_settings.options[key] if @step_settings.options.key?(key)
          return default unless required
          abort_pipeline("Missing required option: #{key.inspect} for step #{name.inspect}")
        end

        ##
        # Get the path to an output directory.
        # If the step_name argument is provided, its output directory is
        # returned. Otherwise, the current step's output directory is returned.
        #
        # @param step_name [String,nil] Optional name of the step whose
        #     directory should be returned.
        # @return [String]
        #
        def output_dir(step_name = nil)
          @pipeline.artifact_dir.output(step_name || name)
        end

        ##
        # Get the path to a private temporary directory for use by this step.
        #
        # @return [String]
        #
        def temp_dir
          @pipeline.artifact_dir.temp(name)
        end

        ##
        # Copy the given item from an input directory
        #
        # @param source_step [String] Name of the source step
        # @param source_path [String] Path to the file or directory to copy
        # @param dest [:component,:repo_root,:temp,:output] Symbolic destination
        # @param dest_path [String,nil] Path in the destination, if different
        #     from the source
        # @param collisions [:error,:replace,:keep] What to do if a collision
        #     occurs
        #
        def copy_from_input(source_step, source_path: nil, dest: :component, dest_path: nil, collisions: nil)
          collisions ||= "error"
          source_dir = output_dir(source_step)
          source_path ||= "."
          dest_path ||= source_path
          dest_dir =
            case dest
            when :component
              component.directory(from: :absolute)
            when :repo_root
              @pipeline.utils.repo_root_directory
            when :output
              output_dir
            when :temp
              temp_dir
            else
              abort_pipeline("Unrecognized destination for copy_from_input: #{source.inspect}")
            end
          source = ::File.expand_path(source_path, source_dir)
          dest = ::File.expand_path(dest_path, dest_dir)
          utils.log("Copying #{source_path.inspect} from step #{source_step.inspect}")
          @pipeline.copy_tree(self, source, dest, source_path, collisions.to_s)
        end

        ##
        # Copy the given item to the output directory
        #
        # @param source [:component,:repo_root,:temp] Symbolic source
        # @param source_path [String] Path to the file or directory to copy
        # @param dest_path [String,nil] Path in the destination, if different
        #     from the source
        # @param collisions [:error,:replace,:keep] What to do if a collision
        #     occurs
        #
        def copy_to_output(source: :component, source_path: nil, dest_path: nil, collisions: nil)
          collisions ||= "error"
          source_path ||= "."
          dest_path ||= source_path
          source_dir =
            case source
            when :component
              component.directory(from: :absolute)
            when :repo_root
              @pipeline.utils.repo_root_directory
            when :temp
              temp_dir
            else
              abort_pipeline("Unrecognized source for copy_to_output: #{source.inspect}")
            end
          source = ::File.expand_path(source_path, source_dir)
          dest = ::File.expand_path(dest_path, output_dir)
          utils.log("Copying #{source_path.inspect} to output")
          @pipeline.copy_tree(self, source, dest, source_path, collisions.to_s)
        end

        # ---- called internally from the pipeline ----

        # @private
        def mark_will_run!
          @will_run = true
        end

        # @private
        def primary?
          @step_impl.respond_to?(:primary?) && @step_impl.primary?(self)
        end

        # @private
        def dependencies
          if @step_impl.respond_to?(:dependencies)
            Array(@step_impl.dependencies(self))
          else
            []
          end
        end

        # @private
        def run!
          @step_impl.run(self) if @step_impl.respond_to?(:run)
        end
      end

      ##
      # Construct the pipeline context
      #
      def initialize(repository:, component:, version:, performer_result:, artifact_dir:, dry_run:, git_remote:)
        @repository = repository
        @component = component
        @release_version = version
        @performer_result = performer_result
        @artifact_dir = artifact_dir
        @dry_run = dry_run
        @git_remote = git_remote || "origin"
        @utils = repository.utils
        @steps = []
        @steps_locked = false
      end

      attr_reader :repository
      attr_reader :component
      attr_reader :release_version
      attr_reader :performer_result
      attr_reader :artifact_dir
      attr_reader :dry_run
      attr_reader :git_remote
      attr_reader :utils

      ##
      # Add a step
      #
      # @param step_settings [Toys::Release::StepSettings] step settings
      # @return [Toys::Release::Pipeline::StepContext]
      #
      def add_step(step_settings)
        raise "Steps locked" if @steps_locked
        step = StepContext.new(self, step_settings)
        @steps << step
        step
      end

      ##
      # Resolve which steps should run
      #
      def resolve_run
        @utils.log("Resolving which steps to run...")
        @steps_locked = true
        @steps.each_with_index do |step, index|
          if step.requested?
            @utils.log("Step #{step.name} is explicitly requested in config")
            mark_step_index(index)
          elsif step.primary?
            @utils.log("Step #{step.name} declares itself as a primary step")
            mark_step_index(index)
          end
        end
        self
      end

      ##
      # Run the runnable steps in the pipeline
      #
      def run
        @steps.each do |step|
          unless step.will_run?
            @utils.log("Skipping step #{step.name}")
            next
          end
          begin
            clean_repo(step)
            pull_inputs(step)
            @utils.log("Running step #{step.name}")
            step.run!
            @utils.log("Completed step #{step.name}")
            push_outputs(step)
          rescue StepExit => e
            @utils.log("Exited step #{step.name}: #{e.message}")
            # Continue
          rescue PipelineExit => e
            @utils.log("Aborted pipeline: #{e.message}")
            return nil
          end
        end
        self
      end

      ##
      # @private
      #
      def copy_tree(step, src, dest, src_name, collisions)
        if ::File.directory?(src)
          if ::File.exist?(dest) && !::File.directory?(dest)
            return if handle_copy_collision(step, collisions, dest, src_name) == :keep
          end
          ::FileUtils.mkdir_p(dest)
          ::Dir.children(src).each do |child|
            copy_tree(step, ::File.join(src, child), ::File.join(dest, child),
                      ::File.join(src_name, child), collisions)
          end
        elsif ::File.exist?(src)
          if ::File.exist?(dest)
            return if handle_copy_collision(step, collisions, dest, src_name) == :keep
          end
          ::FileUtils.copy_entry(src, dest)
        else
          step.abort_pipeline("Unable to copy #{src_name} because it does not exist")
        end
      end

      private

      ##
      # @private
      # Recursive routine to mark steps as runnable
      #
      def mark_step_index(index)
        step = @steps[index]
        return if step.will_run?
        step.mark_will_run!
        step.input_settings.each do |input_settings|
          dep_index = @steps[...index].find_index { |item| item.name == input_settings.step_name }
          unless dep_index
            @utils.error("Input dependency #{input_settings.name} not found before step #{step.name}")
            return nil
          end
          @utils.log("Step #{@steps[dep_index].name} requested as a dependency of #{step.name}")
          mark_step_index(dep_index)
        end
        step.dependencies.each do |dep_name|
          dep_index = @steps[...index].find_index { |item| item.name == dep_name }
          unless dep_index
            @utils.error("Dependency #{dep_name} not found before step #{step.name}")
            return nil
          end
          @utils.log("Step #{dep_name} requested as a dependency of #{step.name}")
          mark_step_index(dep_index)
        end
      end

      ##
      # @private
      # Entry point to clean the repo
      #
      def clean_repo(step)
        if step.option("clean") == false
          @utils.log("Pre-cleaning disabled by the step #{step.name}")
          return
        end
        @utils.log("Pre-cleaning the repo for step #{step.name}")
        count = clean_tree(nil)
        @utils.log("Cleaned #{count} items") if count.positive?
        @utils.exec(["git", "reset", "--hard"])
      end

      ##
      # @private
      # Recursive repo cleaner
      #
      def clean_tree(subdir)
        count = 0
        ::Dir.children(subdir || ".").each do |child|
          next if child == ".git"
          child = ::File.join(subdir, child) if subdir
          if ::File.directory?(child)
            clean_tree(child)
          elsif !git_files.include?(child)
            count += 1
            @utils.log("Cleaning: #{child}")
            ::FileUtils.rm_rf(child)
          end
        end
        count
      end

      ##
      # @private
      # Return all files known by git
      #
      def git_files
        @git_files ||= @utils.capture(["git", "ls-files"], e: true).strip.split("\n")
      end

      ##
      # @private
      # Pull data from all inputs for the given step
      #
      def pull_inputs(step)
        step.input_settings.each do |input|
          next if input.dest == "none"
          source_path = input.source_path || "."
          dest_path = input.dest_path || source_path
          source = ::File.expand_path(source_path, @artifact_dir.output(input.step_name))
          dest_dir =
            case input.dest
            when "component"
              step.component.directory(from: :absolute)
            when "repo_root"
              @utils.repo_root_directory
            when "output"
              step.output_dir
            when "temp"
              step.temp_dir
            else
              step.abort_pipeline("Unrecognized destination for input: #{input.dest.inspect}")
            end
          dest = ::File.expand_path(dest_path, dest_dir)
          @utils.log("Copying #{source_path.inspect} from step #{input.step_name.inspect}")
          copy_tree(step, source, dest, source_path, input.collisions)
        end
      end

      ##
      # @private
      # Push data to output from the given step
      #
      def push_outputs(step)
        step.output_settings.each do |output|
          source_path = output.source_path || "."
          dest_path = output.dest_path || source_path
          source_dir =
            case output.source
            when "component"
              step.component.directory(from: :absolute)
            when "repo_root"
              @utils.repo_root_directory
            when "temp"
              step.temp_dir
            else
              step.abort_pipeline("Unrecognized source for output: #{output.source.inspect}")
            end
          source = ::File.expand_path(source_path, source_dir)
          dest = ::File.expand_path(dest_path, step.output_dir)
          @utils.log("Copying #{source_path.inspect} to output")
          copy_tree(step, source, dest, source_path, output.collisions)
        end
      end

      ##
      # @private
      # Handle a collision during copy_tree.
      # Returns :keep or :replace
      #
      def handle_copy_collision(step, collisions, dest, src_name)
        case collisions
        when "keep"
          :keep
        when "replace"
          ::FileUtils.remove_entry(dest)
          :replace
        else
          step.abort_pipeline("Unable to copy #{src_name} because it already exists at the destination")
        end
      end
    end
  end
end
