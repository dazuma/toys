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
    cli.add_source do
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
    cli.add_source do
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

  describe "color" do
    let(:env_names) { ["NO_COLOR", "FORCE_COLOR", "TERM"] }
    let(:tty_output) do
      out = ::StringIO.new
      def out.tty?
        true
      end
      out
    end

    before do
      @saved_env = env_names.to_h { |name| [name, ::ENV[name]] }
      env_names.each { |name| ::ENV.delete(name) }
    end

    after do
      @saved_env.each { |name, value| ::ENV[name] = value }
    end

    def use_color_for(*highline_args)
      cli.add_source do
        tool "foo" do
          include :highline, *highline_args
          to_run do
            exit(highline.use_color? ? 1 : 2)
          end
        end
      end
      cli.run("foo") == 1
    end

    it "uses color when the highline output is a tty" do
      assert(use_color_for($stdin, tty_output))
    end

    it "does not use color when the highline output is not a tty" do
      refute(use_color_for($stdin, ::StringIO.new))
    end

    it "does not use color when NO_COLOR is set" do
      ::ENV["NO_COLOR"] = "1"
      refute(use_color_for($stdin, tty_output))
    end

    it "uses color when FORCE_COLOR is set" do
      ::ENV["FORCE_COLOR"] = "1"
      assert(use_color_for($stdin, ::StringIO.new))
    end
  end
end
