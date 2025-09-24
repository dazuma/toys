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
    if @toys_ci_failed_jobs.empty?
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
  def initialize(all_flag: "all",
                 all_default: true,
                 fail_fast_flag: "fail_fast",
                 fail_fast_default: false)
    @jobs = []
    @all_flag = all_flag
    @all_default = all_default
    @fail_fast_flag = fail_fast_flag
    @fail_fast_default = fail_fast_default
    @prerun = nil
  end

  def job(name, enable_flag: nil, tool: nil, exec: nil, env: nil, chdir: nil, &block)
    @jobs <<
      if block && !tool && !exec
        [:block, name, enable_flag, block]
      elsif !block && tool && !exec
        [:tool, name, enable_flag, tool, env, chdir]
      elsif !block && !tool && exec
        [:exec, name, enable_flag, exec, env, chdir]
      else
        raise Toys::ToolDefinitionError, "add_job must take a tool, exec, or block"
      end
  end

  def on_prerun(&block)
    @prerun = block
  end

  attr_accessor :all_flag, :all_default, :fail_fast_flag, :fail_fast_default

  attr_reader :jobs, :prerun

  on_expand do |template|
    if template.all_flag
      flag(template.all_flag) do
        flags "--[no-]#{template.all_flag.to_s.tr('_', '-')}"
        default template.all_default
        desc "Run all jobs by default (default is #{template.all_default})"
      end
    end

    if template.fail_fast_flag
      flag(template.fail_fast_flag) do
        flags "--[no-]#{template.fail_fast_flag.to_s.tr('_', '-')}"
        default template.fail_fast_default
        desc "Terminate CI as soon as a job fails (default is #{template.fail_fast_default})"
      end
    end

    flag_group(desc: "Jobs") do
      template.jobs.each do |job|
        if job[2]
          flag(job[2]) do
            flags "--[no-]#{job[2].to_s.tr('_', '-')}"
            desc "Run or omit the job \"#{job[0]}\""
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
      toys_ci_template.jobs.each do |job|
        enabled = toys_ci_enabled_value(job)
        case job[0]
        when :tool
          toys_ci_job(job[1], enabled: enabled, tool: job[3], env: job[4], chdir: job[5])
        when :exec
          toys_ci_job(job[1], enabled: enabled, exec: job[3], env: job[4], chdir: job[5])
        when :block
          toys_ci_job(job[1], enabled: enabled, &job[3])
        end
      end
      toys_ci_report_results
    end

    def toys_ci_fail_fast_value
      if toys_ci_template.fail_fast_flag
        self[toys_ci_template.fail_fast_flag]
      else
        toys_ci_template.fail_fast_default
      end
    end

    def toys_ci_enabled_value(job)
      enabled = self[job[2]] if job[2]
      return enabled unless enabled.nil?
      if toys_ci_template.all_flag
        self[toys_ci_template.all_flag]
      else
        toys_ci_template.all_default
      end
    end
  end
end
