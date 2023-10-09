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
flag :minitest_version, "--minitest-version=VERSION", default: "~> 5.0",
     desc: "Set the minitest version requirement (default is ~>5.0)"
flag :minitest_focus, "--minitest-focus[=VERSION]",
     desc: "Make minitest-focus available during the run"
flag :minitest_rg, "--minitest-rg[=VERSION]",
     desc: "Make minitest-rg available during the run"
flag :minitest_compat, "--[no-]minitest-compat",
     desc: "Set MT_COMPAT to retain compatibility with certain old plugins"

include :exec
include :gems
include :terminal

def run
  env = ruby_env
  ENV["MT_COMPAT"] = env["MT_COMPAT"] if env.key?("MT_COMPAT")
  load_minitest_gems
  result = exec_ruby(ruby_args, log_cmd: "Starting minitest...", env: env)
  if result.error?
    logger.error("Minitest failed!")
    exit(result.exit_code)
  end
end

def load_minitest_gems
  gem "minitest", minitest_version
  require "minitest"
  if minitest_focus
    minitest_focus = "~> 1.0" if minitest_focus == true
    gem "minitest-focus", minitest_focus
    require "minitest/focus"
  end
  if minitest_rg
    minitest_rg = "~> 5.0" if minitest_rg == true
    gem "minitest-rg", minitest_rg
    require "minitest/rg"
  end
end

def ruby_env
  case minitest_compat
  when true
    { "MT_COMPAT" => "true" }
  when false
    { "MT_COMPAT" => nil }
  else
    {}
  end
end

def ruby_args
  args = []
  args << "-w" if warnings
  args << "-I#{::Toys::CORE_LIB_PATH}#{::File::PATH_SEPARATOR}#{::Toys::LIB_PATH}"
  args << "-e" << ruby_code.join("\n")
  args << "--"
  args << "--seed" << seed if seed
  args << "--verbose" if verbosity.positive?
  args << "--name" << name if name
  args << "--exclude" << exclude if exclude
  args
end

def ruby_code
  code = []
  code << "gem 'minitest', '= #{::Minitest::VERSION}'"
  code << "require 'minitest/autorun'"
  if minitest_focus
    code << "gem 'minitest-focus', '= #{::Minitest::Test::Focus::VERSION}'"
    code << "require 'minitest/focus'"
  end
  if minitest_rg
    code << "gem 'minitest-rg', '= #{::MiniTest::RG::VERSION}'"
    code << "require 'minitest/rg'"
  end
  code << "require 'toys'"
  code << "require 'toys/testing'"
  if directory
    code << "Toys::Testing.toys_custom_paths(#{::File.absolute_path(directory).inspect})"
    code << "Toys::Testing.toys_include_builtins(false)"
  end
  find_test_files.each do |file|
    code << "load '#{file}'"
  end
  code
end

def find_test_files
  glob = ".test/**/test_*.rb"
  glob = "**/#{glob}" if recursive
  glob = "#{tool_dir}/#{glob}"
  test_files = Dir.glob(glob)
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
