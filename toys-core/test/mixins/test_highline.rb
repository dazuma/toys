# frozen_string_literal: true

require "helper"
require "toys/standard_mixins/highline"

describe Toys::StandardMixins::Highline do
  let(:logger) {
    Logger.new(StringIO.new).tap do |lgr|
      lgr.level = Logger::WARN
    end
  }
  let(:executable_name) { "toys" }
  let(:cli) {
    Toys::CLI.new(executable_name: executable_name, logger: logger, middleware_stack: [])
  }

  it "provides a highline instance" do
    cli.add_config_block do
      tool "foo" do
        include :highline
        def run
          exit(highline.is_a?(::HighLine) ? 1 : 2)
        end
      end
    end
    assert_equal(1, cli.run("foo"))
  end

  it "supports say" do
    cli.add_config_block do
      tool "foo" do
        include :highline
        def run
          say "hello"
        end
      end
    end
    assert_output("hello\n") do
      cli.run("foo")
    end
  end
end
