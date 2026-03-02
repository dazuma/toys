# frozen_string_literal: true

desc "Run tool tests"

flag :directory, "-d", "--directory PATH",
     desc: "Run tests from the given directory"
flag :seed, "-s", "--seed SEED",
     desc: "Sets random seed."
flag :warnings, "-w", "--[no-]warnings",
     default: true,
     desc: "Turn on Ruby warnings (defaults to true)"
flag :include_name, "-n", "-i", "--name PATTERN", "--include PATTERN",
     desc: "Filter run on /regexp/ or string."
flag :exclude_name, "-e", "-x", "--exclude PATTERN",
     desc: "Exclude /regexp/ or string from run."
flag :recursive, "--[no-]recursive", default: true,
     desc: "Recursively test subtools (default is true)"
flag :tool, "-t TOOL", "--tool TOOL", default: "",
     desc: "Run tests only for tools under the given path"
flag :minitest_version, "--minitest-version=VERSION", "--minitest=VERSION",
     desc: "Set the minitest version requirement during runs where no Gemfile is present"
flag :minitest_focus, "--minitest-focus[=VERSION]",
     desc: "Make minitest-focus available during runs where no Gemfile is present"
flag :minitest_mock, "--minitest-mock[=VERSION]",
     desc: "Make minitest-mock available during runs where no Gemfile is present"
flag :minitest_rg, "--minitest-rg[=VERSION]",
     desc: "Make minitest-rg available during runs where no Gemfile is present"
flag :use_gems, "--use-gem=SPEC",
     default: [], handler: :push,
     desc: "Install the given gem with version requirements during runs where no Gemfile is present"
flag :minitest_compat, "--[no-]minitest-compat", "--[no-]mt-compat",
     desc: "Set MT_COMPAT to retain compatibility with certain old plugins"
flag :expand_globs, "--globs", "--expand-globs",
     desc: "Expand globs in the test file arguments."

remaining_args :tests,
               complete: :file_system,
               desc: "Paths to the tests to run (defaults to all tests)"

include :exec
include :gems
include :terminal

def run
  setup_mt_compat
  final_code = 0
  jobs = determine_jobs
  if jobs.empty?
    puts "WARNING: No test files found", :yellow, :bold
    exit
  end
  jobs.each do |job|
    puts "Running #{job.name}", :bold
    result = run_job(job)
    if result.success?
      puts "Succeeded: #{job.name}", :green, :bold
    else
      puts "Failed: #{job.name} (code=#{result.effective_code})", :red, :bold
      final_code = 1
    end
  end
  exit(final_code)
end

def setup_mt_compat
  case minitest_compat
  when true
    ENV["MT_COMPAT"] = "true"
  when false
    ENV.delete("MT_COMPAT")
  end
end

Job = ::Struct.new(:name, :globs, :tests, :gemfile)

def run_job(job)
  args = ["system", "test", "_internal"]
  args.concat(verbosity_flags)
  args << "--seed" << seed if seed
  args << "--no-warnings" unless warnings
  args << "--name" << include_name if include_name
  args << "--exclude" << exclude_name if exclude_name
  if job.gemfile
    args << "--gemfile-path" << job.gemfile
  else
    add_gem_args(args)
  end
  args << "--globs" if job.globs
  args << "--preload-code" << preload_code
  args.concat(Array(job.globs || job.tests))
  exec_separate_tool(args)
end

def preload_code
  <<~RUBY
    require "toys"
    require "toys/testing"
    Toys::Testing.toys_custom_paths(#{base_dir.inspect})
    Toys::Testing.toys_include_builtins(false)
  RUBY
end

def add_gem_args(args)
  use_gems_hash = use_gems.to_h do |spec|
    name, version = spec.strip.split(/\s*,\s*/, 2)
    [name, version]
  end
  use_gems_hash["minitest"] = minitest_version
  use_gems_hash["minitest-mock"] = minitest_mock if minitest_mock
  use_gems_hash["minitest-focus"] = minitest_focus if minitest_focus
  use_gems_hash["minitest-rg"] = minitest_rg if minitest_rg
  if ::ENV["TOYS_DEV"] == "true"
    args << "--libs" << ::Toys::CORE_LIB_PATH unless use_gems_hash["toys-core"]
    args << "--libs" << ::Toys::LIB_PATH unless use_gems_hash["toys"]
  else
    use_gems_hash["toys"] ||= ::Toys::VERSION
  end
  use_gems_hash.each do |name, versions|
    versions = nil if versions == true
    args << "--use-gem" << [name, versions].compact.join(",")
  end
end

def determine_jobs
  return determine_jobs_from_tests unless tests.empty?
  jobs = []
  job = build_job_under(::File.join(tool_dir, ".test"))
  jobs << job if job
  if recursive
    ::Dir.glob("#{tool_dir}/*/**/.test").sort.each do |test_dir|
      job = build_job_under(test_dir)
      jobs << job if job
    end
  end
  jobs
end

def determine_jobs_from_tests
  jobs = []
  paths_by_test_dir = {}
  paths_without_gemfile = []
  preprocess_tests.each do |path|
    test_dir = find_test_dir(path)
    if test_dir
      (paths_by_test_dir[test_dir] ||= []) << path
    else
      paths_without_gemfile << path
    end
  end
  paths_by_test_dir.each do |test_dir, paths|
    gemfile_path = ::File.join(test_dir, "Gemfile")
    if ::File.file?(gemfile_path)
      jobs << Job.new("specified tests under #{test_dir}", nil, paths, gemfile_path)
    else
      paths_without_gemfile.concat(paths)
    end
  end
  unless paths_without_gemfile.empty?
    name_prefix = jobs.empty? ? "" : "remaining "
    jobs << Job.new("#{name_prefix}specified tests", nil, paths_without_gemfile, nil)
  end
  jobs
end

def preprocess_tests
  results = []
  tests.each do |elem|
    if expand_globs
      glob_results = ::Dir.glob(elem)
      if glob_results.empty?
        logger.warn("Pattern did not match any test files: #{elem}")
      else
        glob_results.each do |path|
          results << ::File.realpath(path)
        end
      end
    else
      begin
        results << ::File.realpath(elem)
      rescue ::Errno::ENOENT
        logger.error("Unable to find file: #{elem}")
        exit(1)
      end
    end
  end
  results
end

def find_test_dir(path)
  dir = ::File.dirname(path)
  while dir != path
    return dir if ::File.basename(dir) == ".test"
    path = dir
    dir = ::File.dirname(dir)
  end
  nil
end

def build_job_under(test_path)
  return nil unless ::File.directory?(test_path)
  globs = ["#{test_path}/**/test_*.rb", "#{test_path}/**/*_test.rb"]
  globs.delete_if { |glob| ::Dir.glob(glob).empty? }
  return nil if globs.empty?
  gemfile_path = ::File.join(test_path, "Gemfile")
  gemfile_path = nil unless ::File.file?(gemfile_path)
  Job.new("tests under #{test_path}", globs, nil, gemfile_path)
end

def tool_dir
  @tool_dir ||= begin
    words = cli.loader.split_path(tool)
    dir = base_dir
    unless words.empty?
      dir = ::File.join(dir, *words)
      unless ::File.directory?(dir)
        logger.warn("No such directory: #{dir}")
        exit
      end
    end
    dir
  end
end

def base_dir
  @base_dir ||=
    if directory
      unless ::File.directory?(directory)
        logger.error("Directory not found: #{directory}")
        exit(1)
      end
      ::File.realpath(directory)
    else
      dir = ::File.realpath(::Dir.getwd)
      loop do
        candidate = ::File.join(dir, ::Toys::StandardCLI::CONFIG_DIR_NAME)
        break candidate if ::File.directory?(candidate)
        parent = ::File.dirname(dir)
        if parent == dir
          logger.error("Unable to find a Toys directory")
          exit(1)
        end
        dir = parent
      end
    end
end

expand :minitest do |mt|
  mt.name = "_internal"
  mt.files = []
end
