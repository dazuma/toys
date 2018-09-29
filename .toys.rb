# frozen_string_literal: true

# Copyright 2018 Daniel Azuma
#
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# * Redistributions of source code must retain the above copyright notice,
#   this list of conditions and the following disclaimer.
# * Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
# * Neither the name of the copyright holder, nor the names of any other
#   contributors to this software, may be used to endorse or promote products
#   derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
;

unless ::ENV["TOYS_CORE_LIB_PATH"] == ::File.absolute_path(::File.join(__dir__, "toys-core", "lib"))
  puts "NOTE: Rerunning toys binary from the local repo\n\n"
  ::Kernel.exec(::File.join(__dir__, "toys-dev"), *::ARGV)
end

include :gems, suppress_confirm: true
gem "highline", "~> 2.0"
gem "minitest", "~> 5.11"
gem "minitest-focus", "~> 1.1"
gem "minitest-rg", "~> 5.2"
gem "redcarpet", "~> 3.4"
gem "rubocop", "~> 0.59.1"
gem "yard", "~> 0.9.16"

tool "install" do
  desc "Build and install the current gems"

  include :exec, exit_on_nonzero_status: true
  include :terminal

  def handle_gem(gem_name, version)
    puts("**** Installing #{gem_name} #{version} from local build...", :bold, :cyan)
    ::Dir.chdir(::File.join(__dir__, gem_name)) do
      subcli = cli.child.add_config_path(".toys.rb")
      exit_on_nonzero_status(subcli.run("build"))
      exec(["gem", "install", "pkg/#{gem_name}-#{version}.gem"])
    end
  end

  def run
    version = capture(["./toys-dev", "system", "version"], chdir: __dir__).strip
    handle_gem("toys-core", version)
    handle_gem("toys", version)
  end
end

tool "ci" do
  desc "CI target that runs all tests for both gems"

  long_desc "The CI tool runs all CI checks for both gems, including unit" \
              " tests, rubocop, and documentation checks. It is useful for" \
              " running tests in normal development, as well as being the" \
              " entrypoint for CI systems like Travis. Any failure will" \
              " result in a nonzero result code."

  include :exec, exit_on_nonzero_status: true
  include :terminal

  def handle_gem(gem_name)
    puts("**** CHECKING #{gem_name.upcase} GEM...", :bold, :cyan)
    ::Dir.chdir(::File.join(__dir__, gem_name)) do
      exec_tool(["ci"], cli: cli.child.add_config_path(".toys.rb"))
    end
    puts("**** #{gem_name.upcase} GEM OK.", :bold, :cyan)
  end

  def run
    handle_gem("toys-core")
    handle_gem("toys")
  end
end

tool "yardoc" do
  desc "Generates yardoc for both gems"

  include :exec, exit_on_nonzero_status: true
  include :terminal

  def handle_gem(gem_name)
    puts("**** Generating Yardoc for #{gem_name}...", :bold, :cyan)
    ::Dir.chdir(::File.join(__dir__, gem_name)) do
      exec_tool(["yardoc"], cli: cli.child.add_config_path(".toys.rb"))
    end
  end

  def run
    handle_gem("toys-core")
    handle_gem("toys")
  end
end

tool "clean" do
  desc "Cleans both gems"

  include :exec, exit_on_nonzero_status: true
  include :terminal

  def handle_gem(gem_name)
    puts("**** Cleaning #{gem_name}...", :bold, :cyan)
    ::Dir.chdir(::File.join(__dir__, gem_name)) do
      exec_tool(["clean"], cli: cli.child.add_config_path(".toys.rb"))
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
      exec_tool(["release", "-y"], cli: cli.child.add_config_path(".toys.rb"))
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
