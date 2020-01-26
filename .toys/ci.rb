# frozen_string_literal: true

# Copyright 2019 Daniel Azuma
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
# IN THE SOFTWARE.
;

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
