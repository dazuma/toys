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

require "helper"
require "toys/standard_middleware/add_verbosity_flags"

describe Toys::StandardMiddleware::AddVerbosityFlags do
  let(:logger) {
    Logger.new(StringIO.new).tap do |lgr|
      lgr.level = Logger::WARN
    end
  }
  let(:binary_name) { "toys" }
  def make_cli(opts = {})
    middleware = [[Toys::StandardMiddleware::AddVerbosityFlags, opts]]
    Toys::CLI.new(binary_name: binary_name, logger: logger, middleware_stack: middleware)
  end

  it "recognizes short verbose flag" do
    cli = make_cli
    cli.add_config_block do
      tool "foo" do
        def run
          exit(10 + verbosity)
        end
      end
    end
    assert_equal(11, cli.run("foo", "-v"))
  end

  it "recognizes long verbose flag" do
    cli = make_cli
    cli.add_config_block do
      tool "foo" do
        def run
          exit(10 + verbosity)
        end
      end
    end
    assert_equal(11, cli.run("foo", "--verbose"))
  end

  it "recognizes short quiet flag" do
    cli = make_cli
    cli.add_config_block do
      tool "foo" do
        def run
          exit(10 + verbosity)
        end
      end
    end
    assert_equal(9, cli.run("foo", "-q"))
  end

  it "recognizes long quiet flag" do
    cli = make_cli
    cli.add_config_block do
      tool "foo" do
        def run
          exit(10 + verbosity)
        end
      end
    end
    assert_equal(9, cli.run("foo", "--quiet"))
  end

  it "allows multiple flags" do
    cli = make_cli
    cli.add_config_block do
      tool "foo" do
        def run
          exit(10 + verbosity)
        end
      end
    end
    assert_equal(12, cli.run("foo", "-vvqv"))
  end

  it "supports custom verbose flag" do
    cli = make_cli(verbose_flags: ["--abc"])
    cli.add_config_block do
      tool "foo" do
        def run
          exit(10 + verbosity)
        end
      end
    end
    assert_equal(12, cli.run("foo", "--abc", "--abc"))
  end

  it "supports custom quiet flag" do
    cli = make_cli(quiet_flags: ["--abc"])
    cli.add_config_block do
      tool "foo" do
        def run
          exit(10 + verbosity)
        end
      end
    end
    assert_equal(8, cli.run("foo", "--abc", "--abc"))
  end

  it "allows disabling of verbose flag" do
    cli = make_cli
    cli.add_config_block do
      tool "foo" do
        disable_flag "--verbose"
        def run
          exit(usage_error ? -1 : 10 + verbosity)
        end
      end
    end
    assert_equal(-1, cli.run("foo", "--verbose"))
    assert_equal(11, cli.run("foo", "-v"))
  end

  it "allows disabling of quiet flag" do
    cli = make_cli
    cli.add_config_block do
      tool "foo" do
        disable_flag "--quiet"
        def run
          exit(usage_error ? -1 : 10 + verbosity)
        end
      end
    end
    assert_equal(-1, cli.run("foo", "--quiet"))
    assert_equal(9, cli.run("foo", "-q"))
  end
end
