# frozen_string_literal: true

require "helper"
require "toys/utils/terminal"
require "toys/standard_mixins/terminal"

describe Toys::StandardMixins::Terminal do
  let(:logger) {
    Logger.new(StringIO.new).tap do |lgr|
      lgr.level = Logger::WARN
    end
  }
  let(:executable_name) { "toys" }
  let(:cli) {
    Toys::CLI.new(executable_name: executable_name, logger: logger, middleware_stack: [])
  }

  it "provides a terminal instance" do
    cli.add_config_block do
      tool "foo" do
        include :terminal
        def run
          exit(terminal.is_a?(::Toys::Utils::Terminal) ? 1 : 2)
        end
      end
    end
    assert_equal(1, cli.run("foo"))
  end

  it "supports styled puts with forced style" do
    cli.add_config_block do
      tool "foo" do
        include :terminal, styled: true
        def run
          puts "hello", :bold
        end
      end
    end
    assert_output("\e[1mhello\n\e[0m") do
      cli.run("foo")
    end
  end

  it "supports unstyled puts by default when capturing" do
    cli.add_config_block do
      tool "foo" do
        include :terminal
        def run
          puts "hello", :bold
        end
      end
    end
    assert_output("hello\n") do
      cli.run("foo")
    end
  end
end
