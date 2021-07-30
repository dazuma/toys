# frozen_string_literal: true

desc "Run tool tests"

flag :directory, "-d", "--directory PATH",
     desc: "Run tests from the given directory"
flag :seed, "-s", "--seed SEED",
     desc: "Sets random seed."
flag :warnings, "-w", "--[no-]warnings",
     default: true,
     desc: "Turn on Ruby warnings (defaults to true)"
flag :name, "-n", "--name PATTERN",
     desc: "Filter run on /regexp/ or string."
flag :exclude, "-e", "--exclude PATTERN",
     desc: "Exclude /regexp/ or string from run."
flag :recursive, "--[no-]recursive", default: true,
     desc: "Recursively test subtools (default is true)"
flag :tool, "-t TOOL", "--tool TOOL", default: "",
     desc: "Run tests only for tools under the given path"

include :exec
include :gems
include :terminal

def run
  gem "minitest", "~> 5.0"
  ::Dir.chdir(tool_dir)
  test_files = find_test_files
  result = exec_ruby(ruby_args, in: :controller, log_cmd: "Starting minitest...") do |controller|
    controller.in.puts("gem 'minitest', '~> 5.0'")
    controller.in.puts("require 'minitest/autorun'")
    controller.in.puts("require 'toys'")
    controller.in.puts("require 'toys/testing'")
    test_files.each do |file|
      controller.in.puts("load '#{file}'")
    end
  end
  if result.error?
    logger.error("Minitest failed!")
    exit(result.exit_code)
  end
end

def find_test_files
  glob = ".test/**/test_*.rb"
  glob = "**/#{glob}" if recursive
  test_files = ::Dir.glob(glob)
  if test_files.empty?
    logger.warn("No test files found")
    exit
  end
  test_files.each do |file|
    logger.info("Loading: #{file}")
  end
  test_files
end

def tool_dir
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

def base_dir
  return ::File.absolute_path(directory) if directory
  dir = ::Dir.getwd
  loop do
    candidate = ::File.join(dir, ::Toys::StandardCLI::CONFIG_DIR_NAME)
    return candidate if ::File.directory?(candidate)
    parent = ::File.dirname(dir)
    if parent == dir
      logger.error("Unable to find a Toys directory")
      exit(1)
    end
    dir = parent
  end
end

def ruby_args
  args = []
  args << "-w" if warnings
  args << "-I#{::Toys::CORE_LIB_PATH}#{::File::PATH_SEPARATOR}#{::Toys::LIB_PATH}"
  args << "-"
  args << "--seed" << seed if seed
  args << "--verbose" if verbosity.positive?
  args << "--name" << name if name
  args << "--exclude" << exclude if exclude
  args
end
