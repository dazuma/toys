# frozen_string_literal: true

require "toys-core"

module Toys
  module CI
    ##
    # A template that can be used to implement a CI tool.
    #
    # This template generates flags and implementation methods in the current
    # tool to implement CI. In particular, it generates the `run` method
    # itself. If you need more control over the CI tool's implementation,
    # consider using {Toys::CI::Mixin} which provides a lower-level interface.
    #
    # To implement a CI tool using this template, simply expand the template
    # and provide the necessary configuration, including specifying at least
    # one CI task to run. The generated tool will use {Toys::CI::Mixin} under
    # the hood.
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
    #       # Activate the toys-ci gem and expand the template
    #       load_gem "toys-ci"
    #       expand Toys::CI::Template do |ci|
    #         ci.all_flag = true
    #         ci.tool_job("Tests", ["test"], flag: :tests)
    #         ci.tool_job("Rubocop", ["rubocop"], flag: :rubocop)
    #       end
    #     end
    #
    class Template
      include ::Toys::Template

      ##
      # Create the CI template.
      # This template provides no direct arguments.
      # All configuration of this template should be done by calling methods
      # on the template in the expand block.
      #
      def initialize
        @jobs = []
        @collections = []
        @all_flag = nil
        @only_flag = nil
        @jobs_disabled_by_default = nil
        @fail_fast_flag = nil
        @fail_fast_default = false
        @base_ref_flag = nil
        @use_github_base_ref_flag = nil
        @prerun = nil
      end

      ##
      # Add a job implemented by a tool call.
      #
      # @param name [String] A user-visible name for the job. Required.
      # @param tool [Array<String>] The Toys tool to run. Required.
      # @param flag [Symbol] A flag key to control whether the job will run.
      #     If provided, it will be used to generate two flags that can be
      #     passed to the CI job. For example, passing `:unit_tests` will
      #     generate the flags `--unit-tests` and `--no-unit-tests` and set the
      #     context value `:unit_tests`. If not provided, no flag is generated
      #     and runnability will be determined by the "all" or "only" flag.
      # @param override_flags [String,Array<String>,nil] Generated flags to use
      #     instead of the ones implied by the `:flag` argument. These must be
      #     specified without the leading `--`, and will automatically have
      #     `--[no-]` prepended. Optional. If not specified or nil, the flags
      #     fall back to those implied by the `:flag` argument.
      # @param trigger_paths [Array<String>,String,nil] An array of file or
      #     directory paths, relative to the repo root, that must have changes
      #     in order to trigger the job. If not specified, the job is always
      #     triggered.
      # @param env [Hash{String=>String}] Environment variables to set during
      #     the run. Optional.
      # @param chdir [String] The working directory for the run. Optional.
      #
      def tool_job(name, tool, flag: nil, override_flags: nil, trigger_paths: nil, env: nil, chdir: nil)
        if override_flags && !flag
          raise ::Toys::ToolDefinitionError, "override_flags is meaningless without a flag"
        end
        @jobs << ToolJob.new(name, flag, Array(override_flags), trigger_paths, tool, env, chdir)
        self
      end

      ##
      # Add a job implemented by an external process.
      #
      # @param name [String] A user-visible name for the job. Required.
      # @param cmd [Array<String>] The command to run. Required.
      # @param flag [Symbol] A flag key to control whether the job will run.
      #     If provided, it will be used to generate two flags that can be
      #     passed to the CI job. For example, passing `:unit_tests` will
      #     generate the flags `--unit-tests` and `--no-unit-tests` and set the
      #     context value `:unit_tests`. If not provided, no flag is generated
      #     and runnability will be determined by the "all" or "only" flag.
      # @param override_flags [String,Array<String>,nil] Generated flags to use
      #     instead of the ones implied by the `:flag` argument. These must be
      #     specified without the leading `--`, and will automatically have
      #     `--[no-]` prepended. Optional. If not specified or nil, the flags
      #     fall back to those implied by the `:flag` argument.
      # @param trigger_paths [Array<String>,String,nil] An array of file or
      #     directory paths, relative to the repo root, that must have changes
      #     in order to trigger the job. If not specified, the job is always
      #     triggered.
      # @param env [Hash{String=>String}] Environment variables to set during
      #     the run. Optional.
      # @param chdir [String] The working directory for the run. Optional.
      #
      def cmd_job(name, cmd, flag: nil, override_flags: nil, trigger_paths: nil, env: nil, chdir: nil)
        if override_flags && !flag
          raise ::Toys::ToolDefinitionError, "override_flags is meaningless without a flag"
        end
        @jobs << CmdJob.new(name, flag, Array(override_flags), trigger_paths, cmd, env, chdir)
        self
      end

      ##
      # Add a job implemented by a block.
      #
      # The block should perform a CI job and return a boolean indicating
      # whether or not the job succeeded. It will execute in the tool execution
      # context, with `self` set to the `Toys::Context`.
      #
      # @param name [String] A user-visible name for the job. Required.
      # @param block [Proc] A block that runs this job. Required.
      # @param flag [Symbol,nil] A flag key to control whether the job will run.
      #     If provided, it will be used to generate two flags that can be
      #     passed to the CI job. For example, passing `:unit_tests` will
      #     generate the flags `--unit-tests` and `--no-unit-tests` and set the
      #     context value `:unit_tests`. If not provided, no flag is generated
      #     and runnability will be determined by the "all" or "only" flag.
      # @param override_flags [String,Array<String>,nil] Generated flags to use
      #     instead of the ones implied by the `:flag` argument. These must be
      #     specified without the leading `--`, and will automatically have
      #     `--[no-]` prepended. Optional. If not specified or nil, the flags
      #     fall back to those implied by the `:flag` argument.
      # @param trigger_paths [Array<String>,String,nil] An array of file or
      #     directory paths, relative to the repo root, that must have changes
      #     in order to trigger the job. If not specified, the job is always
      #     triggered.
      #
      def job(name, flag: nil, override_flags: nil, trigger_paths: nil, &block)
        if override_flags && !flag
          raise ::Toys::ToolDefinitionError, "override_flags is meaningless without a flag"
        end
        @jobs << BlockJob.new(name, flag, Array(override_flags), trigger_paths, block)
        self
      end

      ##
      # Define a collection of jobs that can be enabled/disabled as a group.
      #
      # @param name [String] A user-visible name for the collection. Required.
      # @param flag [Symbol] A flag key to control the collection. Required.
      #     Used to define two flags that can be passed to the CI job. For
      #     example, passing `:unit_tests` will generate the flags
      #     `--unit-tests` and `--no-unit-tests` and set the context value
      #     `:unit_tests`.
      # @param override_flags [String,Array<String>,nil] Generated flags to use
      #     instead of the ones implied by the `:flag` argument. These must be
      #     specified without the leading `--`, and will automatically have
      #     `--[no-]` prepended. Optional. If not specified or nil, the flags
      #     fall back to those implied by the `:flag` argument.
      # @param job_flags [Array<Symbol>] The individual job flags that will be
      #     controlled as a group by this collection. Must be nonempty.
      #
      def collection(name, flag, job_flags, override_flags: nil)
        if job_flags.empty?
          raise ::Toys::ToolDefinitionError, "You must provide at least one entry in job_flags"
        end
        @collections << Collection.new(name, flag, Array(override_flags), job_flags)
        self
      end

      ##
      # Provide a block that will be run at the beginning of the CI job.
      # The block will run in the tool execution context, with `self` set to
      # the `Toys::Context`.
      #
      # @param block [Proc] The block to execute.
      #
      def before_run(&block)
        @prerun = block
      end

      ##
      # Create a flag that will enable all jobs. All jobs will otherwise be
      # disabled by default. This setting is mutually exclusive with
      # {#only_flag=} and {#jobs_disabled_by_default=}.
      #
      # The value can either be the flag key as a symbol, `true` to use the
      # default (which is `:all`), or `false` to disable such a flag.
      # For example, passing `true` will define the flag `--all` which will set
      # the context key `:all`.
      #
      # @param value [Symbol,boolean]
      #
      def all_flag=(value)
        @all_flag = value
      end

      ##
      # Create a flag that will disable all jobs. All jobs will otherwise be
      # enabled by default. This setting is mutually exclusive with
      # {#all_flag=} and {#jobs_disabled_by_default=}.
      #
      # The value can either be the flag key as a symbol, `true` to use the
      # default (which is `:only`), or `false` to disable such a flag.
      # For example, passing `true` will define the flag `--only` which will
      # set the context key `:only`.
      #
      # @param value [Symbol,boolean]
      #
      def only_flag=(value)
        @only_flag = value
      end

      ##
      # If set to true, all jobs are disabled by default unless explicitly
      # enabled by their individual flags.
      #
      # This setting is mutually exclusive with {#all_flag=} and {#only_flag=}.
      # If you set up one of those flags, the default enabling behavior is also
      # set implicitly.
      #
      # @param value [boolean]
      #
      def jobs_disabled_by_default=(value)
        @jobs_disabled_by_default = value
      end

      ##
      # Create flags that will enable and disable fail-fast. The flag should be
      # specified by symbol, and the actual flag will be set accordingly. You
      # can also use the value `true` which will set the default `:fail_fast`.
      # For example, passing `true` will define the flags `--fail-fast` and
      # `--no-fail-fast`.
      #
      # @param value [Symbol,boolean]
      #
      def fail_fast_flag=(value)
        @fail_fast_flag = value
      end

      ##
      # Set the default value of fail-fast. You can also create flags that can
      # override this value using {fail_fast_flag=}. Default is false.
      #
      # @param value [boolean]
      #
      def fail_fast_default=(value)
        @fail_fast_default = value
      end

      ##
      # Create a flag that can be used to specify the base ref for the change
      # directly. This can be used to filter CI jobs based on what has changed.
      #
      # A change base ref provided in this way will override any obtained from
      # other means, such as from the GitHub environment using
      # {#use_github_base_ref_flag=}.
      #
      # @param value [Symbol,boolean] If a symbol, it is used as the flag
      #     key for a flag that specifies the base ref. You can also pass
      #     `true` to use the default, `:base_ref`.
      #
      def base_ref_flag=(value)
        @base_ref_flag = value
      end

      ##
      # Create a flag that enables obtaining the change base ref from the
      # GitHub workflow environment. This can be used to filter CI jobs based
      # on what has changed in a GitHub Actions workflow. The flag should be
      # specified by symbol, and the actual flag will be set accordingly. You
      # can also use the value `true` which will set the default
      # `:use_github_base_ref`. For example, passing `true` will define the
      # flags `--use-github-base-ref` and `--no-use-github-base-ref`.
      #
      # @param value [Symbol,boolean]
      #
      def use_github_base_ref_flag=(value)
        @use_github_base_ref_flag = value
      end

      # @private
      BlockJob = ::Struct.new(:name, :flag, :override_flags, :trigger_paths, :block)

      # @private
      ToolJob = ::Struct.new(:name, :flag, :override_flags, :trigger_paths, :tool, :env, :chdir)

      # @private
      CmdJob = ::Struct.new(:name, :flag, :override_flags, :trigger_paths, :cmd, :env, :chdir)

      # @private
      Collection = ::Struct.new(:name, :flag, :override_flags, :job_flags)

      # @private
      attr_reader :jobs

      # @private
      attr_reader :collections

      # @private
      attr_reader :prerun

      # @private
      attr_reader :jobs_disabled_by_default

      # @private
      attr_reader :fail_fast_default

      # @private
      def all_flag?
        !@all_flag.nil? && @all_flag != false
      end

      # @private
      def only_flag?
        !@only_flag.nil? && @only_flag != false
      end

      # @private
      def fail_fast_flag?
        !@fail_fast_flag.nil? && @fail_fast_flag != false
      end

      # @private
      def base_ref_flag?
        !@base_ref_flag.nil? && @base_ref_flag != false
      end

      # @private
      def use_github_base_ref_flag?
        !@use_github_base_ref_flag.nil? && @use_github_base_ref_flag != false
      end

      # @private
      def all_flag(desired_format = :symbol)
        format_flag(@all_flag, :all, desired_format)
      end

      # @private
      def only_flag(desired_format = :symbol)
        format_flag(@only_flag, :only, desired_format)
      end

      # @private
      def fail_fast_flag(desired_format = :symbol)
        format_flag(@fail_fast_flag, :fail_fast, desired_format)
      end

      # @private
      def base_ref_flag(desired_format = :symbol)
        format_flag(@base_ref_flag, :base_ref, desired_format)
      end

      # @private
      def use_github_base_ref_flag(desired_format = :symbol)
        format_flag(@use_github_base_ref_flag, :use_github_base_ref, desired_format)
      end

      # @private
      def format_flag(raw_flag, default_symbol, desired_format)
        value = raw_flag == true ? default_symbol : raw_flag
        desired_format == :hyphenated ? value.to_s.tr("_", "-") : value
      end

      on_expand do |template|
        if template.all_flag? && !template.only_flag? && template.jobs_disabled_by_default.nil?
          template.jobs_disabled_by_default = true
          flag(template.all_flag) do
            flags("--#{template.all_flag(:hyphenated)}")
            desc("Run all jobs unless explicitly disabled by their flags." \
                 " (If not set, only explicitly enabled jobs run.)")
          end
        elsif !template.all_flag? && template.only_flag? && template.jobs_disabled_by_default.nil?
          template.jobs_disabled_by_default = false
          flag(template.only_flag) do
            flags("--#{template.only_flag(:hyphenated)}")
            desc("Run only jobs explicitly enabled by their flags." \
                 " (If not set, all jobs run unless explicitly disabled.)")
          end
        elsif !template.all_flag? && !template.only_flag?
          template.jobs_disabled_by_default ||= false
        else
          raise ::Toys::ToolDefinitionError, "all_flag, only_flag, and jobs_disabled_by_default are mutually exclusive"
        end

        if template.fail_fast_flag?
          flag(template.fail_fast_flag) do
            flags("--[no-]#{template.fail_fast_flag(:hyphenated)}")
            default(template.fail_fast_default)
            desc("Terminate CI as soon as any job fails (default is #{template.fail_fast_default})")
          end
        end

        if template.base_ref_flag?
          flag(template.base_ref_flag) do
            flags("--#{template.base_ref_flag(:hyphenated)} REF")
            desc("Filter jobs that do not match changes since this git ref")
          end
        end

        if template.use_github_base_ref_flag?
          flag(template.use_github_base_ref_flag) do
            flags("--[no-]#{template.use_github_base_ref_flag(:hyphenated)}")
            desc("Look up the change base from GitHub to determine which jobs to filter")
          end
        end

        flag_desc_suffix =
          if template.all_flag?
            "(Jobs run by default if --#{template.all_flag(:hyphenated)} is set.)"
          elsif template.only_flag?
            "(Jobs run by default unless --#{template.only_flag(:hyphenated)} is set.)"
          elsif template.jobs_disabled_by_default
            "(Jobs do not run by default.)"
          else
            "(All jobs run by default.)"
          end

        flag_group(desc: "Jobs") do
          template.jobs.each do |job|
            next unless job.flag
            flag(job.flag) do
              if job.override_flags.empty?
                hyphenated_flag = job.flag.to_s.tr("_", "-")
                flags("--[no-]#{hyphenated_flag}")
              else
                job.override_flags.each { |override_flag| flags("--[no-]#{override_flag}") }
              end
              desc("Run or omit the job \"#{job.name}\". #{flag_desc_suffix}")
            end
          end
        end

        unless template.collections.empty?
          flag_group(desc: "Collections") do
            template.collections.each do |collection|
              Array(collection.job_flags).each do |job_flag|
                if template.jobs.none? { |job| job.flag == job_flag }
                  raise ::Toys::ToolDefinitionError,
                        "Collection \"#{collection.name}\" referenced nonexistent job flag: #{job_flag}"
                end
              end
              flag(collection.flag) do
                if collection.override_flags.empty?
                  hyphenated_flag = collection.flag.to_s.tr("_", "-")
                  flags("--[no-]#{hyphenated_flag}")
                else
                  collection.override_flags.each { |override_flag| flags("--[no-]#{override_flag}") }
                end
                desc("Run or omit all \"#{collection.name}\". #{flag_desc_suffix}")
              end
            end
          end
        end

        static :toys_ci_template, template

        include ::Toys::CI::Mixin

        def run
          ::Dir.chdir(context_directory) do
            instance_exec(&toys_ci_template.prerun) if toys_ci_template.prerun
            toys_ci_init(fail_fast: toys_ci_fail_fast_value, limit_by_changes_since: toys_ci_resolve_base_ref)
            toys_ci_resolve_collections
            toys_ci_run_all_jobs
            toys_ci_report_results
          end
        end

        def toys_ci_resolve_base_ref
          base_ref = toys_ci_template.base_ref_flag? ? self[toys_ci_template.base_ref_flag] : nil
          if toys_ci_template.use_github_base_ref_flag? && self[toys_ci_template.use_github_base_ref_flag]
            base_ref ||= toys_ci_github_event_base_sha
          end
          base_ref
        end

        def toys_ci_fail_fast_value
          if toys_ci_template.fail_fast_flag?
            self[toys_ci_template.fail_fast_flag]
          else
            toys_ci_template.fail_fast_default
          end
        end

        def toys_ci_resolve_collections
          toys_ci_template.collections.each do |collection|
            value = self[collection.flag]
            next if value.nil?
            Array(collection.job_flags).each do |job_flag|
              set(job_flag, value) if self[job_flag].nil?
            end
          end
        end

        def toys_ci_run_all_jobs
          toys_ci_template.jobs.each do |job|
            next unless toys_ci_enabled_value(job.flag)
            case job
            when ToolJob
              toys_ci_tool_job(job.name, job.tool, trigger_paths: job.trigger_paths, env: job.env, chdir: job.chdir)
            when CmdJob
              toys_ci_cmd_job(job.name, job.cmd, trigger_paths: job.trigger_paths, env: job.env, chdir: job.chdir)
            when BlockJob
              toys_ci_job(job.name, trigger_paths: job.trigger_paths, &job.block)
            end
          end
        end

        def toys_ci_enabled_value(flag)
          flag_value = self[flag] if flag
          return flag_value unless flag_value.nil?
          if toys_ci_template.all_flag?
            self[toys_ci_template.all_flag]
          elsif toys_ci_template.only_flag?
            !self[toys_ci_template.only_flag]
          else
            !toys_ci_template.jobs_disabled_by_default
          end
        end
      end
    end
  end
end
