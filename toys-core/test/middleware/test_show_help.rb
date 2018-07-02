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

require "helper"
require "stringio"
require "toys/standard_middleware/show_help"

describe Toys::StandardMiddleware::ShowHelp do
  let(:logger) {
    Logger.new(StringIO.new).tap do |lgr|
      lgr.level = Logger::WARN
    end
  }
  let(:binary_name) { "toys" }
  let(:string_io) { ::StringIO.new }
  def make_cli(opts = {})
    middleware = [[Toys::StandardMiddleware::ShowHelp, opts.merge(stream: string_io)]]
    Toys::CLI.new(binary_name: binary_name, logger: logger, middleware_stack: middleware)
  end

  it "causes a tool to respond to help flags" do
    cli = make_cli(help_flags: true)
    cli.add_config_block do
      tool "foo" do
      end
    end
    cli.run("foo", "--help")
    assert_match(/SYNOPSIS.*toys foo/m, string_io.string)
  end

  it "causes a tool to respond to usage flags" do
    cli = make_cli(usage_flags: true)
    cli.add_config_block do
      tool "foo" do
      end
    end
    cli.run("foo", "--usage")
    assert_match(/Usage:\s+toys foo/, string_io.string)
  end

  it "implements fallback execution" do
    cli = make_cli(fallback_execution: true)
    cli.add_config_block do
      tool "foo" do
      end
    end
    cli.run("foo")
    assert_match(/SYNOPSIS.*toys foo/m, string_io.string)
  end

  it "supports root args" do
    cli = make_cli(help_flags: true, allow_root_args: true)
    cli.add_config_block do
      tool "foo" do
        tool "bar" do
        end
      end
    end
    cli.run("--help", "foo", "bar")
    assert_match(/SYNOPSIS.*toys foo bar/m, string_io.string)
  end

  it "supports search flag" do
    cli = make_cli(fallback_execution: true, search_flags: true)
    cli.add_config_block do
      tool "foo" do
        desc "beyond all recognition"
      end
      tool "bar" do
        desc "was met"
      end
    end
    cli.run("--search", "bar")
    refute_match(/foo/, string_io.string)
    assert_match(/bar - was met/, string_io.string)
  end

  it "does not recurse by default" do
    cli = make_cli(fallback_execution: true)
    cli.add_config_block do
      tool "foo" do
        desc "beyond all recognition"
        tool "bar" do
          desc "was met"
        end
      end
    end
    cli.run
    refute_match(/bar - was met/, string_io.string)
  end

  it "supports default recursive listing" do
    cli = make_cli(fallback_execution: true, default_recursive: true)
    cli.add_config_block do
      tool "foo" do
        desc "beyond all recognition"
        tool "bar" do
          desc "was met"
        end
      end
    end
    cli.run
    assert_match(/bar - was met/, string_io.string)
  end

  it "supports set-recursive flag" do
    cli = make_cli(fallback_execution: true, recursive_flags: true)
    cli.add_config_block do
      tool "foo" do
        desc "beyond all recognition"
        tool "bar" do
          desc "was met"
        end
      end
    end
    cli.run("--recursive")
    assert_match(/bar - was met/, string_io.string)
  end

  it "supports clear-recursive flag" do
    cli = make_cli(fallback_execution: true, default_recursive: true, recursive_flags: true)
    cli.add_config_block do
      tool "foo" do
        desc "beyond all recognition"
        tool "bar" do
          desc "was met"
        end
      end
    end
    cli.run("--no-recursive")
    refute_match(/bar - was met/, string_io.string)
  end
end
