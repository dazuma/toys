# frozen_string_literal: true

desc "CI target that runs all tests for both gems"

long_desc "The CI tool runs all CI checks for both gems, including unit" \
            " tests, rubocop, and documentation checks. It is useful for" \
            " running tests in normal development, as well as being the" \
            " entrypoint for CI systems. Any failure will result in a" \
            " nonzero result code."

include :terminal
include :exec

def handle_gem(gem_name)
  puts("**** CHECKING #{gem_name.upcase} GEM...", :bold, :cyan)
  ::Dir.chdir(::File.join(context_directory, gem_name)) do
    result = exec_separate_tool("ci")
    if result.success?
      puts("**** #{gem_name.upcase} GEM OK.", :bold, :cyan)
    else
      puts("**** #{gem_name.upcase} GEM FAILED!", :red, :bold)
      exit(result.exit_code)
    end
  end
end

def run
  handle_gem("toys-core")
  handle_gem("toys")
end

tool "init" do
  desc "Initialize the environment for CI systems"

  include :exec
  include :terminal

  def run
    changed = false
    if exec(["git", "config", "--global", "--get", "user.email"], out: :null).error?
      exec(["git", "config", "--global", "user.email", "hello@example.com"],
           exit_on_nonzero_status: true)
      changed = true
    end
    if exec(["git", "config", "--global", "--get", "user.name"], out: :null).error?
      exec(["git", "config", "--global", "user.name", "Hello Ruby"],
           exit_on_nonzero_status: true)
      changed = true
    end
    if changed
      puts("**** Environment is now set up for CI", :bold, :green)
    else
      puts("**** Environment was already set up for CI", :bold, :yellow)
    end
  end
end
