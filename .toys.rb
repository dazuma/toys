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
  use :exec
  script do
    set ::Toys::Context::EXIT_ON_NONZERO_STATUS, true
    ::Dir.chdir(::File.dirname(tool.definition_path)) do
      version = capture("./toys-dev system version").strip
      ::Dir.chdir("toys-core") do
        cli = new_cli.add_config_path(".toys.rb")
        run("build", cli: cli)
        sh "gem install pkg/toys-core-#{version}.gem"
      end
      ::Dir.chdir("toys") do
        cli = new_cli.add_config_path(".toys.rb")
        run("build", cli: cli)
        sh "gem install pkg/toys-#{version}.gem"
      end
    end
  end
end

tool "ci" do
  desc "CI target that runs tests and rubocop for both gems"
  use :exec
  use :highline
  helper(:validate_dir) do
    cli = new_cli.add_config_path(".toys.rb")
    puts color("** Checking tests...", :cyan)
    run("test", cli: cli)
    puts color("** Tests ok.", :cyan)
    puts color("** Checking rubocop...", :cyan)
    run("rubocop", cli: cli)
    puts color("** Rubocop ok.", :cyan)
    puts color("** Checking yardoc...", :cyan)
    exec(["yardoc", "--no-stats", "--no-cache", "--no-output", "--fail-on-warning"])
    stats = capture(["yard", "stats", "--list-undoc"])
    if stats =~ /Undocumented\sObjects:/
      puts stats
      exit(1)
    end
    puts color("** Yardoc ok.", :cyan)
  end
  script do
    set ::Toys::Context::EXIT_ON_NONZERO_STATUS, true
    ::Dir.chdir(::File.dirname(tool.definition_path)) do
      ::Dir.chdir("toys-core") do
        puts color("**** CHECKING TOYS-CORE GEM...", :bold, :cyan)
        validate_dir
        puts color("**** TOYS-CORE GEM OK.", :bold, :cyan)
      end
      ::Dir.chdir("toys") do
        puts color("**** CHECKING TOYS GEM ...", :bold, :cyan)
        validate_dir
        puts color("**** TOYS GEM OK.", :bold, :cyan)
      end
    end
  end
end

tool "yardoc" do
  desc "Generates yardoc for both gems"
  use :exec
  script do
    set ::Toys::Context::EXIT_ON_NONZERO_STATUS, true
    ::Dir.chdir(::File.dirname(tool.definition_path)) do
      ::Dir.chdir("toys-core") do
        exec "yardoc"
      end
      ::Dir.chdir("toys") do
        exec "yardoc"
      end
    end
  end
end

tool "clean" do
  desc "Cleans both gems"
  use :exec
  script do
    set ::Toys::Context::EXIT_ON_NONZERO_STATUS, true
    ::Dir.chdir(::File.dirname(tool.definition_path)) do
      ::Dir.chdir("toys-core") do
        cli = new_cli.add_config_path(".toys.rb")
        run("clean", cli: cli)
      end
      ::Dir.chdir("toys") do
        cli = new_cli.add_config_path(".toys.rb")
        run("clean", cli: cli)
      end
    end
  end
end

tool "release" do
  desc "Releases both gems"
  use :exec
  use :highline
  script do
    set ::Toys::Context::EXIT_ON_NONZERO_STATUS, true
    ::Dir.chdir(::File.dirname(tool.definition_path)) do
      version = capture("./toys-dev system version").strip
      exit(1) unless agree("Release toys #{version}? (y/n) ")
      ::Dir.chdir("toys-core") do
        cli = new_cli.add_config_path(".toys.rb")
        run("release", "-y", cli: cli)
      end
      ::Dir.chdir("toys") do
        cli = new_cli.add_config_path(".toys.rb")
        run("release", "-y", cli: cli)
      end
      sh "git tag v#{version}"
      sh "git push origin v#{version}"
    end
  end
end
