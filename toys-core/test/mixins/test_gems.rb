# frozen_string_literal: true

require "helper"
require "toys/utils/gems"
require "toys/standard_mixins/gems"

describe Toys::StandardMixins::Gems do
  let(:logger) {
    Logger.new(StringIO.new).tap do |lgr|
      lgr.level = Logger::WARN
    end
  }
  let(:executable_name) { "toys" }
  let(:cli) {
    Toys::CLI.new(executable_name: executable_name, logger: logger, middleware_stack: [])
  }
  let(:exec_service) { Toys::Utils::Exec.new }

  it "provides a gems instance" do
    test = self
    cli.add_config_block do
      tool "foo" do
        include :gems
        test.assert_instance_of(Toys::Utils::Gems, gems)
        def run
          exit(gems.is_a?(Toys::Utils::Gems) ? 1 : 2)
        end
      end
    end
    assert_equal(1, cli.run("foo"))
  end

  it "passes arguments to gems util constructor" do
    exec_service.exec(["gem", "uninstall", "highline", "--version=2.0.1"], out: :null)
    cli.add_config_block do
      tool "foo" do
        include :gems
        def run
          begin
            gem("highline", "2.0.1", on_missing: :error)
          rescue Toys::Utils::Gems::ActivationFailedError
            exit(1)
          end
          exit(2)
        end
      end
    end
    assert_equal(1, cli.run("foo"))
  end
end
