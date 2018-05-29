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

tool "install" do
  desc "Build and install the current gems"
  include :exec
  def run
    configure_exec(exit_on_nonzero_status: true)
    ::Dir.chdir(::File.dirname(tool_definition.source_path)) do
      version = capture(["./toys-dev", "system", "version"]).strip
      ::Dir.chdir("toys-core") do
        subcli = cli.child.add_config_path(".toys.rb")
        exit_on_nonzero_status(subcli.run("build"))
        exec(["gem", "install", "pkg/toys-core-#{version}.gem"])
      end
      ::Dir.chdir("toys") do
        subcli = cli.child.add_config_path(".toys.rb")
        exit_on_nonzero_status(subcli.run("build"))
        exec(["gem", "install", "pkg/toys-#{version}.gem"])
      end
    end
  end
end

tool "ci" do
  desc "CI target that runs all tests for both gems"
  include :exec
  def validate_dir(terminal)
    subcli = cli.child.add_config_path(".toys.rb")
    terminal.puts("** Checking tests...", :cyan)
    exit_on_nonzero_status(subcli.run("test"))
    terminal.puts("** Tests ok.", :cyan)
    terminal.puts("** Checking rubocop...", :cyan)
    exit_on_nonzero_status(subcli.run("rubocop"))
    terminal.puts("** Rubocop ok.", :cyan)
    terminal.puts("** Checking yardoc...", :cyan)
    exec(["yardoc", "--no-stats", "--no-cache", "--no-output", "--fail-on-warning"])
    stats = capture(["yard", "stats", "--list-undoc"])
    if stats =~ /Undocumented\sObjects:/
      terminal.puts stats
      exit(1)
    end
    terminal.puts("** Yardoc ok.", :cyan)
  end
  def run
    configure_exec(exit_on_nonzero_status: true)
    terminal = Toys::Utils::Terminal.new
    ::Dir.chdir(::File.dirname(tool_definition.source_path)) do
      ::Dir.chdir("toys-core") do
        terminal.puts("**** CHECKING TOYS-CORE GEM...", :bold, :cyan)
        validate_dir(terminal)
        terminal.puts("**** TOYS-CORE GEM OK.", :bold, :cyan)
      end
      ::Dir.chdir("toys") do
        terminal.puts("**** CHECKING TOYS GEM ...", :bold, :cyan)
        validate_dir(terminal)
        terminal.puts("**** TOYS GEM OK.", :bold, :cyan)
      end
    end
  end
end

tool "yardoc" do
  desc "Generates yardoc for both gems"
  include :exec
  def run
    configure_exec(exit_on_nonzero_status: true)
    ::Dir.chdir(::File.dirname(tool_definition.source_path)) do
      ::Dir.chdir("toys-core") do
        exec(["yardoc"])
      end
      ::Dir.chdir("toys") do
        exec(["yardoc"])
      end
    end
  end
end

tool "clean" do
  desc "Cleans both gems"
  def run
    ::Dir.chdir(::File.dirname(tool_definition.source_path)) do
      ::Dir.chdir("toys-core") do
        subcli = cli.child.add_config_path(".toys.rb")
        status = subcli.run("clean")
        exit(status) unless status.zero?
      end
      ::Dir.chdir("toys") do
        subcli = cli.child.add_config_path(".toys.rb")
        status = subcli.run("clean")
        exit(status) unless status.zero?
      end
    end
  end
end

tool "release" do
  desc "Releases both gems"
  include :exec
  def run
    terminal = Toys::Utils::Terminal.new
    configure_exec(exit_on_nonzero_status: true)
    ::Dir.chdir(::File.dirname(tool_definition.source_path)) do
      version = capture(["./toys-dev", "system", "version"]).strip
      exit(1) unless terminal.confirm("Release toys #{version}?")
      ::Dir.chdir("toys-core") do
        subcli = cli.child.add_config_path(".toys.rb")
        exit_on_nonzero_status(subcli.run("release", "-y"))
      end
      ::Dir.chdir("toys") do
        subcli = cli.child.add_config_path(".toys.rb")
        exit_on_nonzero_status(subcli.run("release", "-y"))
      end
      exec(["git", "tag", "v#{version}"])
      exec(["git", "push", "origin", "v#{version}"])
    end
  end
end
