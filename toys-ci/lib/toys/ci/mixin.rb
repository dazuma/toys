# frozen_string_literal: true

require "toys-core"

module Toys
  module CI
    ##
    # A mixin that provides methods useful for implementing CI tools.
    #
    # This mixin is a lower-level mechanism that depends on you to write your
    # own run method and define any needed flags. For a more batteries-included
    # experience, consider {Toys::CI::Template}, which does that work for you.
    #
    # To implement a CI tool using this mixin, you will:
    #
    # * Include this mixin
    # * Call {toys_ci_init} to initialize the tool
    # * Make calls to various `toys_ci_*_job` methods to run CI jobs
    # * Call {toys_ci_report_results} to report final results
    #
    # This mixin adds various public and private methods, and several instance
    # variables to the tool. All added method and instance variable names begin
    # with `toys_ci_`, so avoid that prefix for any other methods and variables
    # you are using in your tool.
    #
    # @example
    #
    #     # Define the "test" tool
    #     expand :minitest, bundler: true
    #
    #     # Define the "rubocop" tool
    #     expand :rubocop, bundler: true
    #
    #     # Define a "ci" tool that runs both the above, controlled by
    #     # flags "--tests", "--rubocop", and/or "--all".
    #     tool "ci" do
    #       # Activate the toys-ci gem and pull in the mixin
    #       load_gem "toys-ci"
    #       include Toys::CI::Mixin
    #
    #       flag :tests, desc: "Run tests"
    #       flag :rubocop, desc: "Run rubocop"
    #       flag :all, desc: "Run all CI tasks"
    #
    #       def run
    #         toys_ci_init
    #         toys_ci_tool_job("Tests", ["test"]) if tests || all
    #         toys_ci_tool_job("Rubocop", ["rubocop"]) if rubocop || all
    #         toys_ci_report_results
    #       end
    #     end
    #
    module Mixin
      include ::Toys::Mixin

      on_include do
        include :exec unless include?(:exec)
        include :terminal unless include?(:terminal)
      end

      ##
      # Initialize the CI tool. This must be called first before any other
      # `toys_ci_` methods.
      #
      # @param fail_fast [boolean] If true, CI will terminate once any job ends
      #     in failure. Otherwise, all jobs will be run.
      # @param limit_by_changes_since [String,nil] If set to a git ref, finds
      #     all the changed files since that ref, and skips CI jobs that
      #     declare trigger paths that do not match. Optional. By default, no
      #     jobs are skipped for this reason.
      #
      # @return [self]
      #
      def toys_ci_init(fail_fast: false, limit_by_changes_since: nil)
        @toys_ci_fail_fast = fail_fast
        @toys_ci_changed_paths = toys_ci_find_changes_since(limit_by_changes_since)
        @toys_ci_successful_jobs = []
        @toys_ci_failed_jobs = []
        @toys_ci_skipped_jobs = []
        self
      end

      ##
      # Read a GitHub webhook event from the given file path and extract a
      # suitable change base. Returns the SHA, or nil if no GitHub event is
      # found or the event has no suitable base SHA.
      #
      # The result can be passed to the `:limit_by_changes_since` argument of
      # {#toys_ci_init}.
      #
      # @param event_name [String] The name of the GitHub event
      # @param event_path [String] Path to a JSON file
      #
      # @return [String] The SHA for the change base
      # @return [nil] if no change base can be determined
      #
      def toys_ci_github_event_base_sha(event_name, event_path)
        event_name = event_name.to_s
        event_path = event_path.to_s
        return nil if event_name.empty? || event_path.empty?
        event =
          begin
            require "json"
            ::JSON.parse(::File.read(event_path))
          rescue ::SystemCallError, ::JSON::ParserError
            nil
          end
        return nil unless event
        case event_name
        when "push"
          logger.info("Getting change base from push event")
          event["before"]
        when "pull_request"
          logger.info("Getting change base from pull_request event")
          event.dig("pull_request", "base", "sha")
        end
      end

      ##
      # Run a CI job implemented by a tool, and record the results.
      #
      # @param name [String] A user-visible name for the job. Required.
      # @param tool [Array<String>] The Toys tool to run. Required.
      # @param trigger_paths [Array<String>,String,nil] An array of file or
      #     directory paths, relative to the repo root, that must have changes
      #     in order to trigger the job. If not specified, the job is always
      #     triggered.
      # @param env [Hash{String=>String}] Environment variables to set during
      #     the run. Optional.
      # @param chdir [String] The working directory for the run. Optional.
      #
      # @return [:success] If the job succeeded
      # @return [:failure] If the job failed
      # @return [:skipped] If the job was skipped because it did not match the
      #     trigger paths
      #
      def toys_ci_tool_job(name, tool, trigger_paths: nil, env: nil, chdir: nil)
        toys_ci_job(name, trigger_paths: trigger_paths) do
          opts = {name: name}
          opts[:env] = env if env
          opts[:chdir] = chdir if chdir
          exec_separate_tool(tool, **opts).success?
        end
      end

      ##
      # Run a CI job implemented by an external process, and record the results.
      #
      # @param name [String] A user-visible name for the job. Required.
      # @param cmd [Array<String>] The command to run. Required.
      # @param trigger_paths [Array<String>,String,nil] An array of file or
      #     directory paths, relative to the repo root, that must have changes
      #     in order to trigger the job. If not specified, the job is always
      #     triggered.
      # @param env [Hash{String=>String}] Environment variables to set during
      #     the run. Optional.
      # @param chdir [String] The working directory for the run. Optional.
      #
      # @return [:success] If the job succeeded
      # @return [:failure] If the job failed
      # @return [:skipped] If the job was skipped because it did not match the
      #     trigger paths
      #
      def toys_ci_cmd_job(name, cmd, trigger_paths: nil, env: nil, chdir: nil)
        toys_ci_job(name, trigger_paths: trigger_paths) do
          opts = {name: name}
          opts[:env] = env if env
          opts[:chdir] = chdir if chdir
          exec(cmd, **opts).success?
        end
      end

      ##
      # Run a CI job implemented by a block, and record the results.
      #
      # @param name [String] A user-visible name for the job. Required.
      # @param trigger_paths [Array<String>,String,nil] An array of file or
      #     directory paths, relative to the repo root, that must have changes
      #     in order to trigger the job. If not specified, the job is always
      #     triggered.
      # @param block [Proc] The block to run. It will be run with `self` set to
      #     the tool context, and should return true or false indicating
      #     success or failure.
      #
      # @return [:success] If the job succeeded
      # @return [:failure] If the job failed
      # @return [:skipped] If the job was skipped because it did not match the
      #     trigger paths
      #
      def toys_ci_job(name, trigger_paths: nil, &block)
        unless defined?(@toys_ci_successful_jobs)
          raise ::Toys::ToolDefinitionError, "You must call toys_ci_init before running a job"
        end
        return :skipped unless toys_ci_check_trigger_paths(trigger_paths, name)
        puts("**** RUNNING: #{name}", :cyan, :bold)
        result =
          begin
            instance_exec(&block)
          rescue ::StandardError => e
            trace = e.backtrace
            write("#{trace.first}: ")
            puts("#{e.message} (#{e.class})", :bold)
            Array(trace[1..]).each { |line| puts "        from #{line}" }
            false
          end
        toys_ci_job_result(name, result)
      end

      ##
      # Print out a final report of the results, including a summary of the
      # failed jobs. By default, this will also exit and never return. You can
      # instead get the exit value by passing `exit: false`.
      #
      # @param exit [boolean] Whether to exit. Default is true.
      #
      # @return [Integer] The exit value
      #
      def toys_ci_report_results(exit: true) # rubocop:disable Metrics/MethodLength
        unless defined?(@toys_ci_successful_jobs)
          raise ::Toys::ToolDefinitionError, "You must call toys_ci_init before reporting job results"
        end
        success_count = @toys_ci_successful_jobs.size
        failure_count = @toys_ci_failed_jobs.size
        skipped_count = @toys_ci_skipped_jobs.size
        total_job_count = success_count + failure_count + skipped_count
        result =
          if total_job_count.zero?
            puts("**** CI: NO JOBS REQUESTED", :red, :bold)
            puts("Try passing --help to see how to activate CI jobs.")
            2
          elsif failure_count.positive?
            puts("**** CI: SKIPPED #{skipped_count} OF #{total_job_count} JOBS", :bold) unless skipped_count.zero?
            puts("**** CI: FAILED #{failure_count} OF #{success_count + failure_count} RUNNABLE JOBS:", :red, :bold)
            @toys_ci_failed_jobs.each { |name| puts(name, :red) }
            1
          elsif success_count.positive?
            puts("**** CI: SKIPPED #{skipped_count} OF #{total_job_count} JOBS", :bold) unless skipped_count.zero?
            puts("**** CI: ALL #{success_count} RUNNABLE JOBS SUCCEEDED", :green, :bold)
            0
          else
            puts("**** CI: ALL #{skipped_count} JOBS SKIPPED", :yellow, :bold)
            0
          end
        self.exit(result) if exit
        result
      end

      ##
      # @return [Array<String>] The names of the failed jobs so far
      #
      attr_reader :toys_ci_failed_jobs

      ##
      # @return [Array<String>] The names of the successful jobs so far
      #
      attr_reader :toys_ci_successful_jobs

      ##
      # @return [Array<String>] The names of the skipped jobs so far
      #
      attr_reader :toys_ci_skipped_jobs

      ##
      # @private
      # Find all the changed files since the given ref.
      #
      def toys_ci_find_changes_since(ref)
        return nil unless ref
        result = exec(["git", "rev-parse", ref], out: :capture)
        unless result.success?
          logger.error("Unable to find git ref #{ref.inspect}")
          exit(1)
        end
        sha = result.captured_out.strip
        logger.info("Filtering by changes since SHA: #{sha}")
        result = exec(["git", "diff", "--name-only", sha], out: :capture)
        unless result.success?
          logger.error("Unable to get diff since SHA #{sha}")
          exit(1)
        end
        result.captured_out.split("\n")
      end

      ##
      # @private
      #
      def toys_ci_check_trigger_paths(trigger_paths, name)
        return true if !@toys_ci_changed_paths || !trigger_paths
        Array(trigger_paths).each do |trigger_path|
          trigger_dir = trigger_path.end_with?("/") ? trigger_path : "#{trigger_path}/"
          return true if @toys_ci_changed_paths.any? do |changed_path|
            changed_path == trigger_path || changed_path.start_with?(trigger_dir)
          end
        end
        @toys_ci_skipped_jobs << name
        puts("**** SKIPPING BECAUSE NO CHANGES FOUND: #{name}", :cyan, :bold)
        false
      end

      ##
      # @private
      # Report the result of a single job
      #
      # @param name [String] The name of the job
      # @param result [boolean] The result of the job
      # @return [:success] If the result was success
      # @return [:failure] If the result was failure
      #
      def toys_ci_job_result(name, result)
        if result
          @toys_ci_successful_jobs << name
          puts("**** SUCCEEDED: #{name}", :green, :bold)
          :success
        else
          @toys_ci_failed_jobs << name
          puts("**** FAILED: #{name}", :red, :bold)
          if @toys_ci_fail_fast
            puts("TERMINATING CI", :red, :bold)
            exit(1)
          end
          :failure
        end
      end
    end
  end
end
