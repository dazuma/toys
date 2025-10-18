# frozen_string_literal: true

toys_version!("~> 0.15")

mixin "toys-ci" do
  on_include do
    include :exec
    include :terminal
  end

  def toys_ci_init(fail_fast: false)
    Dir.chdir(context_directory)
    @toys_ci_job_count = 0
    @toys_ci_failed_jobs = []
    @toys_ci_fail_fast = fail_fast
  end

  def toys_ci_job(name, enabled: true, tool: nil, exec: nil, env: nil, chdir: nil, &block)
    raise "Not initialized" unless @toys_ci_job_count
    return unless enabled
    @toys_ci_job_count += 1
    puts("**** Running: #{name}", :cyan, :bold)
    result =
      if tool && !exec && !block
        toys_ci_job_run_tool(name, tool, env, chdir)
      elsif !tool && exec && !block
        toys_ci_job_run_exec(name, exec, env, chdir)
      elsif !tool && !exec && block
        toys_ci_job_run_block(block)
      else
        puts("No job implementation found: ci_job expects a block, tool, or exec", :red, :bold)
        false
      end
    toys_ci_job_result(name, result)
  end

  attr_reader :toys_ci_job_count
  attr_reader :toys_ci_failed_jobs

  def toys_ci_report_results
    raise "Not initialized" unless @toys_ci_job_count
    if @toys_ci_job_count.zero?
      puts("**** CI: NO JOBS RUN", :yellow, :bold)
      puts("Try passing --help to see how to activate CI jobs.")
      exit(2)
    elsif @toys_ci_failed_jobs.empty?
      puts("**** CI: ALL #{@toys_ci_job_count} JOBS SUCCEEDED", :green, :bold)
    else
      puts("**** CI: FAILED #{@toys_ci_failed_jobs.size} OF #{@toys_ci_job_count} JOBS:", :red, :bold)
      @toys_ci_failed_jobs.each do |name|
        puts(name, :red)
      end
      exit(1)
    end
  end

  # Private

  def toys_ci_job_run_tool(name, tool, env, chdir)
    opts = {name: name}
    opts[:env] = env if env
    opts[:chdir] = chdir if chdir
    exec_separate_tool(tool, **opts).success?
  end

  def toys_ci_job_run_exec(name, job, env, chdir)
    opts = {name: name}
    opts[:env] = env if env
    opts[:chdir] = chdir if chdir
    exec(job, **opts).success?
  end

  def toys_ci_job_run_block(block)
    instance_eval(&block)
  rescue StandardError => e
    puts(e)
    false
  end

  def toys_ci_job_result(name, result)
    if result
      puts("**** SUCCEEDED: #{name}", :green, :bold)
    else
      @toys_ci_failed_jobs << name
      puts("**** FAILED: #{name}", :red, :bold)
      if @toys_ci_fail_fast
        puts("TERMINATING CI", :red, :bold)
        exit(1)
      end
    end
  end
end

template "toys-ci" do
  def initialize(all_flag: nil,
                 only_flag: nil,
                 jobs_disabled_by_default: nil,
                 fail_fast_flag: nil,
                 fail_fast_default: false)
    @jobs = []
    @collections = []
    @all_flag = all_flag
    @only_flag = only_flag
    @jobs_disabled_by_default = jobs_disabled_by_default
    @fail_fast_flag = fail_fast_flag
    @fail_fast_default = fail_fast_default
    @prerun = nil
  end

  def job(description, flag: nil, tool: nil, exec: nil, env: nil, chdir: nil, &block)
    @jobs <<
      if block && !tool && !exec
        [:block, description, flag, block]
      elsif !block && tool && !exec
        [:tool, description, flag, tool, env, chdir]
      elsif !block && !tool && exec
        [:exec, description, flag, exec, env, chdir]
      else
        raise Toys::ToolDefinitionError, "add_job must take a tool, exec, or block"
      end
  end

  def collection(description, flag, job_flags: nil)
    @collections << [description, flag, job_flags]
  end

  def on_prerun(&block)
    @prerun = block
  end

  attr_writer :all_flag, :only_flag, :jobs_disabled_by_default, :fail_fast_flag, :fail_fast_default

  attr_reader :jobs, :collections, :prerun, :jobs_disabled_by_default, :fail_fast_default

  def all_flag?
    !@all_flag.nil? && @all_flag != false
  end

  def only_flag?
    !@only_flag.nil? && @only_flag != false
  end

  def fail_fast_flag?
    !@fail_fast_flag.nil? && @fail_fast_flag != false
  end

  def all_flag(format = :symbol)
    value = @all_flag == true ? :all : @all_flag
    format == :hyphenated ? value.to_s.tr("_", "-") : value
  end

  def only_flag(format = :symbol)
    value = @only_flag == true ? :only : @only_flag
    format == :hyphenated ? value.to_s.tr("_", "-") : value
  end

  def fail_fast_flag(format = :symbol)
    value = @fail_fast_flag == true ? :fail_fast : @fail_fast_flag
    format == :hyphenated ? value.to_s.tr("_", "-") : value
  end

  on_expand do |template|
    if template.all_flag? && !template.only_flag? && template.jobs_disabled_by_default.nil?
      template.jobs_disabled_by_default = true
      flag(template.all_flag) do
        flags "--#{template.all_flag(:hyphenated)}"
        desc "Run all jobs unless explicitly disabled by their flags. (If not set, only explicitly enabled jobs run.)"
      end
    elsif !template.all_flag? && template.only_flag? && template.jobs_disabled_by_default.nil?
      template.jobs_disabled_by_default = false
      flag(template.only_flag) do
        flags "--#{template.only_flag(:hyphenated)}"
        desc "Run only jobs explicitly enabled by their flags. (If not set, all jobs run unless explicitly disabled.)"
      end
    elsif !template.all_flag? && !template.only_flag?
      template.jobs_disabled_by_default ||= false
    else
      raise Toys::ToolDefinitionError, "all_flag, only_flag, and jobs_disabled_by_default are mutually exclusive"
    end

    if template.fail_fast_flag?
      flag(template.fail_fast_flag) do
        flags "--[no-]#{template.fail_fast_flag(:hyphenated)}"
        default template.fail_fast_default
        desc "Terminate CI as soon as any job fails (default is #{template.fail_fast_default})"
      end
    end

    flag_group(desc: "Jobs") do
      template.jobs.each do |job|
        job_flag = job[2]
        if job_flag
          flag(job_flag) do
            hyphenated_flag = job_flag.to_s.tr("_", "-")
            if template.all_flag? || template.only_flag?
              flags "--[no-]#{hyphenated_flag}"
              suffix =
                if template.all_flag?
                  "(Job runs by default if --#{template.all_flag(:hyphenated)} is set.)"
                else
                  "(Job runs by default unless --#{template.only_flag(:hyphenated)} is set.)"
                end
              desc "Run or omit the job \"#{job[1]}\". #{suffix}"
            elsif template.jobs_disabled_by_default
              flags "--#{hyphenated_flag}"
              desc "Run the job \"#{job[1]}\"."
            else
              flags "--no-#{hyphenated_flag}"
              desc "Omit the job \"#{job[1]}\"."
            end
          end
        end
      end
    end

    unless template.collections.empty?
      flag_group(desc: "Collections") do
        template.collections.each do |collection|
          Array(collection[2]).each do |job_flag|
            if template.jobs.none? { |job| job[2] == job_flag }
              raise Toys::ToolDefinitionError,
                    "Collection #{collection[0].inspect} referenced nonexistent job flag: #{job_flag}"
            end
          end
          flag(collection[1]) do
            hyphenated_flag = collection[1].to_s.tr("_", "-")
            if template.all_flag? || template.only_flag?
              flags "--[no-]#{hyphenated_flag}"
              desc "Run or omit all \"#{collection[0]}\"."
            elsif template.jobs_disabled_by_default
              flags "--#{hyphenated_flag}"
              desc "Run all \"#{collection[0]}\"."
            else
              flags "--no-#{hyphenated_flag}"
              desc "Omit all \"#{collection[0]}\"."
            end
          end
        end
      end
    end

    static :toys_ci_template, template

    include "toys-ci"

    def run
      ::Dir.chdir(context_directory)
      instance_eval(&toys_ci_template.prerun) if toys_ci_template.prerun
      toys_ci_init(fail_fast: toys_ci_fail_fast_value)
      toys_ci_resolve_collections
      toys_ci_run_all_jobs
      toys_ci_report_results
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
        value = self[collection[1]]
        next if value.nil?
        Array(collection[2]).each do |job_flag|
          set(job_flag, value) if self[job_flag].nil?
        end
      end
    end

    def toys_ci_run_all_jobs
      toys_ci_template.jobs.each do |job|
        enabled = toys_ci_enabled_value(job[2])
        case job[0]
        when :tool
          toys_ci_job(job[1], enabled: enabled, tool: job[3], env: job[4], chdir: job[5])
        when :exec
          toys_ci_job(job[1], enabled: enabled, exec: job[3], env: job[4], chdir: job[5])
        when :block
          toys_ci_job(job[1], enabled: enabled, &job[3])
        end
      end
    end

    def toys_ci_enabled_value(flag)
      flag_value = self[flag] if flag
      unless flag_value.nil?
        if toys_ci_template.all_flag? || toys_ci_template.only_flag?
          return flag_value
        else
          return !flag_value ^ toys_ci_template.jobs_disabled_by_default
        end
      end
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
