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

# Run this against local Toys code instead of installed Toys gems.
# This is to support development of Toys itself. Most Toys files should not
# include this.
::Kernel.exec(::File.join(__dir__, "toys-dev"), *::ARGV) unless ::ENV["TOYS_DEV"]

include :gems, suppress_confirm: true
gem "highline", "~> 2.0"
gem "kramdown", "~> 2.1"
gem "minitest", "~> 5.13"
gem "minitest-focus", "~> 1.1"
gem "minitest-rg", "~> 5.2"
gem "rake", "~> 13.0"
gem "rspec", "~> 3.9"
gem "rubocop", "~> 0.77.0"
gem "yard", "~> 0.9.20"

tool "install" do
  desc "Build and install the current gems"

  include :terminal

  def handle_gem(gem_name)
    puts("**** Installing #{gem_name} from local build...", :bold, :cyan)
    ::Dir.chdir(::File.join(__dir__, gem_name)) do
      status = cli.child.add_config_path(".toys.rb").run("install", "-y")
      exit(status) unless status.zero?
    end
  end

  def run
    handle_gem("toys-core")
    handle_gem("toys")
  end
end

tool "ci" do
  desc "CI target that runs all tests for both gems"

  long_desc "The CI tool runs all CI checks for both gems, including unit" \
              " tests, rubocop, and documentation checks. It is useful for" \
              " running tests in normal development, as well as being the" \
              " entrypoint for CI systems. Any failure will result in a" \
              " nonzero result code."

  include :terminal

  def handle_gem(gem_name)
    puts("**** CHECKING #{gem_name.upcase} GEM...", :bold, :cyan)
    ::Dir.chdir(::File.join(__dir__, gem_name)) do
      status = cli.child.add_config_path(".toys.rb").run("ci")
      if status.zero?
        puts("**** #{gem_name.upcase} GEM OK.", :bold, :cyan)
      else
        puts("**** #{gem_name.upcase} GEM FAILED!", :red, :bold)
        exit(1)
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
end

tool "test" do
  desc "Runs tests in both gems"

  include :terminal

  def handle_gem(gem_name)
    puts("**** Testing #{gem_name}...", :bold, :cyan)
    ::Dir.chdir(::File.join(__dir__, gem_name)) do
      status = cli.child.add_config_path(".toys.rb").run("test")
      exit(status) unless status.zero?
    end
  end

  def run
    handle_gem("toys-core")
    handle_gem("toys")
  end
end

tool "yardoc" do
  desc "Generates yardoc for both gems"

  include :terminal

  def handle_gem(gem_name)
    puts("**** Generating Yardoc for #{gem_name}...", :bold, :cyan)
    ::Dir.chdir(::File.join(__dir__, gem_name)) do
      status = cli.child.add_config_path(".toys.rb").run("yardoc")
      exit(status) unless status.zero?
    end
  end

  def run
    handle_gem("toys-core")
    handle_gem("toys")
  end
end

tool "clean" do
  desc "Cleans both gems"

  include :terminal

  def handle_gem(gem_name)
    puts("**** Cleaning #{gem_name}...", :bold, :cyan)
    ::Dir.chdir(::File.join(__dir__, gem_name)) do
      status = cli.child.add_config_path(".toys.rb").run("clean")
      exit(status) unless status.zero?
    end
  end

  def run
    handle_gem("toys-core")
    handle_gem("toys")
  end
end

tool "release" do
  desc "Releases both gems"

  include :exec, exit_on_nonzero_status: true
  include :terminal

  def handle_gem(gem_name)
    puts("**** Releasing #{gem_name}...", :bold, :cyan)
    ::Dir.chdir(gem_name) do
      status = cli.child.add_config_path(".toys.rb").run("release", "-y")
      exit(status) unless status.zero?
    end
  end

  def run
    ::Dir.chdir(__dir__) do
      version = capture(["./toys-dev", "system", "version"]).strip
      exit(1) unless confirm("Release toys #{version}? ")
      handle_gem("toys-core")
      handle_gem("toys")
      puts("**** Tagging v#{version}...", :bold, :cyan)
      exec(["git", "tag", "v#{version}"])
      exec(["git", "push", "origin", "v#{version}"])
      puts("**** Release complete!", :bold, :green)
    end
  end
end

tool "push-docs" do
  desc "Pushes docs to gh-pages"

  flag :tmp_dir, default: "/tmp"
  flag :default, "--[no-]default", default: true

  include :exec, exit_on_nonzero_status: true
  include :fileutils
  include :terminal

  def run
    version = cd(context_directory) do
      capture(["./toys-dev", "system", "version"]).strip
    end
    exit(1) unless confirm("Build and push yardocs for version #{version}? ")
    rm_rf("toys/.yardoc")
    rm_rf("toys/doc")
    rm_rf("toys-core/.yardoc")
    rm_rf("toys-core/doc")
    exec_tool(["yardoc"])
    cd(tmp_dir) do
      rm_rf("toys")
      exec(["git", "clone", "git@github.com:dazuma/toys.git"])
    end
    cd("#{tmp_dir}/toys") do
      exec(["git", "checkout", "gh-pages"])
      rm_rf("gems/toys/v#{version}")
      rm_rf("gems/toys-core/v#{version}")
      cp_r("#{context_directory}/toys/doc", "gems/toys/v#{version}")
      cp_r("#{context_directory}/toys-core/doc", "gems/toys-core/v#{version}")
      if default
        content = ::IO.read("404.html")
        content.sub!(/version = "[\w\.]+";/, "version = \"#{version}\";")
        ::File.open("404.html", "w") do |file|
          file.write(content)
        end
      end
      exec(["git", "add", "."])
      exec(["git", "commit", "-m", "Generate yardocs for version #{version} [ci skip]"])
      exec(["git", "push", "origin", "gh-pages"])
    end
  end
end
