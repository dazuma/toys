# frozen_string_literal: true

toys_version!("~> 0.15")

mixin "toys-ci" do
  on_include do
    include :exec
    include :terminal
  end

  def ci_init
    Dir.chdir(context_directory)
    @ci_job_count = 0
    @ci_failed_jobs = []
  end

  def ci_job(name, tool, env: nil, chdir: nil)
    raise "Not initialized" unless @ci_job_count
    @ci_job_count += 1
    puts("**** Running: #{name}", :cyan, :bold)
    opts = {name: name}
    opts[:env] = env if env
    opts[:chdir] = chdir if chdir
    result = exec_separate_tool tool, **opts
    if result.success?
      puts("**** SUCCEEDED: #{name}", :green, :bold)
    else
      @ci_failed_jobs << name
      puts("**** FAILED: #{name}", :red, :bold)
      if self[:fail_fast]
        puts("TERMINATING CI", :red, :bold)
        exit(1)
      end
    end
  end

  attr_reader :ci_job_count
  attr_reader :ci_failed_jobs

  def ci_report_results
    raise "Not initialized" unless @ci_job_count
    if @ci_failed_jobs.empty?
      puts("**** ALL #{@ci_job_count} JOBS SUCCEEDED", :green, :bold)
    else
      puts("**** FAILED #{@ci_failed_jobs.size} OF #{@ci_job_count} JOBS:", :red, :bold)
      @ci_failed_jobs.each do |name|
        puts(name, :red)
      end
      exit(1)
    end
  end
end
