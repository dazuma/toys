# frozen_string_literal: true

require "helper"
require "stringio"
require "toys/standard_middleware/set_default_descriptions"

describe Toys::StandardMiddleware::SetDefaultDescriptions do
  let(:logger) {
    Logger.new(StringIO.new).tap do |lgr|
      lgr.level = Logger::WARN
    end
  }
  let(:executable_name) { "toys" }
  let(:error_io) { ::StringIO.new }
  def make_cli(**opts)
    middleware = [[Toys::StandardMiddleware::SetDefaultDescriptions, opts]]
    Toys::CLI.new(executable_name: executable_name, logger: logger, middleware_stack: middleware)
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

    it "is set for a delegate" do
      cli = make_cli
      cli.add_config_block do
        tool "foo", delegate_to: "bar" do
          # Empty tool
        end
      end
      tool, _remaining = cli.loader.lookup(["foo"])
      assert_equal('(Delegates to "bar")', tool.desc.to_s)
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
      flag = tool.flags.first
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
      flag = tool.flags.first
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
      flag = tool.flags.first
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
      flag = tool.flags.first
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
      flag = tool.flags.first
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
      flag = tool.flags.first
      assert_equal("Sets the \"bar\" option as type integer (default is 3).",
                   flag.desc.to_s)
    end
  end

  describe "default flag group description" do
    it "is set for an basic group" do
      cli = make_cli
      cli.add_config_block do
        tool "foo" do
          flag_group
        end
      end
      tool, _remaining = cli.loader.lookup(["foo"])
      flag_group = tool.flag_groups.last
      assert_equal("Flags", flag_group.desc.to_s)
      assert(flag_group.long_desc.empty?)
    end

    it "is set for a required group" do
      cli = make_cli
      cli.add_config_block do
        tool "foo" do
          all_required
        end
      end
      tool, _remaining = cli.loader.lookup(["foo"])
      flag_group = tool.flag_groups.last
      assert_equal("Required Flags", flag_group.desc.to_s)
      assert_equal(1, flag_group.long_desc.size)
      assert_equal("These flags are required.", flag_group.long_desc.first.to_s)
    end

    it "is set for an exactly-one group" do
      cli = make_cli
      cli.add_config_block do
        tool "foo" do
          exactly_one
        end
      end
      tool, _remaining = cli.loader.lookup(["foo"])
      flag_group = tool.flag_groups.last
      assert_equal("Flags", flag_group.desc.to_s)
      assert_equal(1, flag_group.long_desc.size)
      assert_equal("Exactly one of these flags must be set.", flag_group.long_desc.first.to_s)
    end

    it "is set for an at-most-one group" do
      cli = make_cli
      cli.add_config_block do
        tool "foo" do
          at_most_one
        end
      end
      tool, _remaining = cli.loader.lookup(["foo"])
      flag_group = tool.flag_groups.last
      assert_equal("Flags", flag_group.desc.to_s)
      assert_equal(1, flag_group.long_desc.size)
      assert_equal("At most one of these flags must be set.", flag_group.long_desc.first.to_s)
    end

    it "is set for an at-least-one group" do
      cli = make_cli
      cli.add_config_block do
        tool "foo" do
          at_least_one
        end
      end
      tool, _remaining = cli.loader.lookup(["foo"])
      flag_group = tool.flag_groups.last
      assert_equal("Flags", flag_group.desc.to_s)
      assert_equal(1, flag_group.long_desc.size)
      assert_equal("At least one of these flags must be set.", flag_group.long_desc.first.to_s)
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
      arg = tool.required_args.first
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
      arg = tool.required_args.first
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
      arg = tool.optional_args.first
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
      arg = tool.optional_args.first
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
      arg = tool.optional_args.first
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
      arg = tool.optional_args.first
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
      arg = tool.remaining_arg
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
      arg = tool.remaining_arg
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
      arg = tool.remaining_arg
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
      arg = tool.remaining_arg
      assert_equal("Remaining arguments are type integer (default is [3, 4, 5]).", arg.desc.to_s)
    end
  end
end
