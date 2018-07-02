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
require "toys/standard_middleware/set_default_descriptions"

describe Toys::StandardMiddleware::SetDefaultDescriptions do
  let(:logger) {
    Logger.new(StringIO.new).tap do |lgr|
      lgr.level = Logger::WARN
    end
  }
  let(:binary_name) { "toys" }
  let(:error_io) { ::StringIO.new }
  def make_cli(opts = {})
    middleware = [[Toys::StandardMiddleware::SetDefaultDescriptions, opts]]
    Toys::CLI.new(binary_name: binary_name, logger: logger, middleware_stack: middleware)
  end

  describe "default tool description" do
    it "is set for a normal tool" do
      cli = make_cli
      cli.add_config_block do
        tool "foo" do
          def run; end
        end
      end
      tool, _remaining = cli.loader.lookup(["foo"])
      assert_equal("(No tool description available)", tool.desc.to_s)
    end

    it "is set for a namespace" do
      cli = make_cli
      cli.add_config_block do
        tool "foo" do
          tool "bar" do
            def run; end
          end
        end
      end
      tool, _remaining = cli.loader.lookup(["foo"])
      assert_equal("(A namespace of tools)", tool.desc.to_s)
    end

    it "is set for the root" do
      cli = make_cli
      tool, _remaining = cli.loader.lookup([])
      assert_equal("Command line tool built using the toys-core gem.", tool.desc.to_s)
    end
  end

  describe "default flag description" do
    it "is set for a boolean with no default" do
      cli = make_cli
      cli.add_config_block do
        tool "foo" do
          flag :bar
          def run; end
        end
      end
      tool, _remaining = cli.loader.lookup(["foo"])
      flag = tool.flag_definitions.first
      assert_equal("Sets the \"bar\" option as type boolean flag.", flag.desc.to_s)
    end

    it "is set for a boolean with a default" do
      cli = make_cli
      cli.add_config_block do
        tool "foo" do
          flag :bar, default: true
          def run; end
        end
      end
      tool, _remaining = cli.loader.lookup(["foo"])
      flag = tool.flag_definitions.first
      assert_equal("Sets the \"bar\" option as type boolean flag (default is true).",
                   flag.desc.to_s)
    end

    it "is set for a string with no default" do
      cli = make_cli
      cli.add_config_block do
        tool "foo" do
          flag :bar, "--barrr=VALUE"
          def run; end
        end
      end
      tool, _remaining = cli.loader.lookup(["foo"])
      flag = tool.flag_definitions.first
      assert_equal("Sets the \"bar\" option as type string.", flag.desc.to_s)
    end

    it "is set for a string with a default" do
      cli = make_cli
      cli.add_config_block do
        tool "foo" do
          flag :bar, "--barrr=VALUE", default: "hello"
          def run; end
        end
      end
      tool, _remaining = cli.loader.lookup(["foo"])
      flag = tool.flag_definitions.first
      assert_equal("Sets the \"bar\" option as type string (default is \"hello\").",
                   flag.desc.to_s)
    end

    it "is set for an integer with no default" do
      cli = make_cli
      cli.add_config_block do
        tool "foo" do
          flag :bar, "--barrr=VALUE", accept: Integer
          def run; end
        end
      end
      tool, _remaining = cli.loader.lookup(["foo"])
      flag = tool.flag_definitions.first
      assert_equal("Sets the \"bar\" option as type integer.", flag.desc.to_s)
    end

    it "is set for an integer with a default" do
      cli = make_cli
      cli.add_config_block do
        tool "foo" do
          flag :bar, "--barrr=VALUE", accept: Integer, default: 3
          def run; end
        end
      end
      tool, _remaining = cli.loader.lookup(["foo"])
      flag = tool.flag_definitions.first
      assert_equal("Sets the \"bar\" option as type integer (default is 3).",
                   flag.desc.to_s)
    end
  end

  describe "default required arg description" do
    it "is set for a string" do
      cli = make_cli
      cli.add_config_block do
        tool "foo" do
          required :bar
          def run; end
        end
      end
      tool, _remaining = cli.loader.lookup(["foo"])
      arg = tool.required_arg_definitions.first
      assert_equal("Required string argument.", arg.desc.to_s)
    end

    it "is set for an integer" do
      cli = make_cli
      cli.add_config_block do
        tool "foo" do
          required :bar, accept: Integer
          def run; end
        end
      end
      tool, _remaining = cli.loader.lookup(["foo"])
      arg = tool.required_arg_definitions.first
      assert_equal("Required integer argument.", arg.desc.to_s)
    end
  end

  describe "default optional arg description" do
    it "is set for a string with no default" do
      cli = make_cli
      cli.add_config_block do
        tool "foo" do
          optional :bar
          def run; end
        end
      end
      tool, _remaining = cli.loader.lookup(["foo"])
      arg = tool.optional_arg_definitions.first
      assert_equal("Optional string argument.", arg.desc.to_s)
    end

    it "is set for a string with a default" do
      cli = make_cli
      cli.add_config_block do
        tool "foo" do
          optional :bar, default: "hello"
          def run; end
        end
      end
      tool, _remaining = cli.loader.lookup(["foo"])
      arg = tool.optional_arg_definitions.first
      assert_equal("Optional string argument (default is \"hello\").", arg.desc.to_s)
    end

    it "is set for an integer with no default" do
      cli = make_cli
      cli.add_config_block do
        tool "foo" do
          optional :bar, accept: Integer
          def run; end
        end
      end
      tool, _remaining = cli.loader.lookup(["foo"])
      arg = tool.optional_arg_definitions.first
      assert_equal("Optional integer argument.", arg.desc.to_s)
    end

    it "is set for an integer with a default" do
      cli = make_cli
      cli.add_config_block do
        tool "foo" do
          optional :bar, accept: Integer, default: 3
          def run; end
        end
      end
      tool, _remaining = cli.loader.lookup(["foo"])
      arg = tool.optional_arg_definitions.first
      assert_equal("Optional integer argument (default is 3).", arg.desc.to_s)
    end
  end

  describe "default remaining args description" do
    it "is set for a string with no default" do
      cli = make_cli
      cli.add_config_block do
        tool "foo" do
          remaining :bar
          def run; end
        end
      end
      tool, _remaining = cli.loader.lookup(["foo"])
      arg = tool.remaining_args_definition
      assert_equal("Remaining arguments are type string (default is []).", arg.desc.to_s)
    end

    it "is set for a string with a default" do
      cli = make_cli
      cli.add_config_block do
        tool "foo" do
          remaining :bar, default: ["hello"]
          def run; end
        end
      end
      tool, _remaining = cli.loader.lookup(["foo"])
      arg = tool.remaining_args_definition
      assert_equal("Remaining arguments are type string (default is [\"hello\"]).", arg.desc.to_s)
    end

    it "is set for an integer with no default" do
      cli = make_cli
      cli.add_config_block do
        tool "foo" do
          remaining :bar, accept: Integer
          def run; end
        end
      end
      tool, _remaining = cli.loader.lookup(["foo"])
      arg = tool.remaining_args_definition
      assert_equal("Remaining arguments are type integer (default is []).", arg.desc.to_s)
    end

    it "is set for an integer with a default" do
      cli = make_cli
      cli.add_config_block do
        tool "foo" do
          remaining :bar, accept: Integer, default: [3, 4, 5]
          def run; end
        end
      end
      tool, _remaining = cli.loader.lookup(["foo"])
      arg = tool.remaining_args_definition
      assert_equal("Remaining arguments are type integer (default is [3, 4, 5]).", arg.desc.to_s)
    end
  end
end
