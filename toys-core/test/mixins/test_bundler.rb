# frozen_string_literal: true

require "helper"
require "toys/utils/gems"
require "toys/standard_mixins/bundler"

describe Toys::StandardMixins::Bundler do
  let(:logger) {
    Logger.new(StringIO.new).tap do |lgr|
      lgr.level = Logger::WARN
    end
  }
  let(:executable_name) { "toys" }
  let(:cli) {
    Toys::CLI.new(executable_name: executable_name, logger: logger, middleware_stack: [])
  }
  let(:gemfile_dir) {
    File.join(File.dirname(File.dirname(__dir__)), "test-data", "gems-cases", "bundle-without-toys")
  }
  let(:gemfile_path) { File.join(gemfile_dir, "Gemfile") }
  let(:gemfile_dir2) {
    File.join(File.dirname(File.dirname(__dir__)), "test-data", "gems-cases", "bundle-with-compatible-toys")
  }
  let(:gemfile_path2) { File.join(gemfile_dir2, "Gemfile") }

  class FakeGemsService
    def initialize
      @bundle_args = nil
    end

    def bundle(**kwargs)
      @bundle_args = kwargs
    end

    attr_reader :bundle_args
  end

  it "runs setup at initialize" do
    test = self
    fake_gems = FakeGemsService.new
    my_gemfile_dir = gemfile_dir
    my_gemfile_path = gemfile_path

    cli.add_config_block do
      tool "foo" do
        include :bundler, search_dirs: my_gemfile_dir
        test.assert_nil(fake_gems.bundle_args)
        to_run do
          exit(1) unless fake_gems.bundle_args
          exit(2) unless fake_gems.bundle_args[:gemfile_path] == my_gemfile_path
        end
      end
    end

    ::Toys::Utils::Gems.stub(:new, fake_gems) do
      assert_equal(0, cli.run("foo"))
    end
  end

  it "runs setup manually" do
    test = self
    fake_gems = FakeGemsService.new
    my_gemfile_dir = gemfile_dir
    my_gemfile_dir2 = gemfile_dir2
    my_gemfile_path2 = gemfile_path2

    cli.add_config_block do
      tool "foo" do
        include :bundler, setup: :manual, search_dirs: my_gemfile_dir
        test.assert_nil(fake_gems.bundle_args)
        to_run do
          exit(1) if fake_gems.bundle_args
          exit(2) if bundler_setup?
          bundler_setup(search_dirs: my_gemfile_dir2)
          exit(3) unless bundler_setup?
          exit(4) unless fake_gems.bundle_args
          exit(5) unless fake_gems.bundle_args[:gemfile_path] == my_gemfile_path2
        end
      end
    end

    ::Toys::Utils::Gems.stub(:new, fake_gems) do
      assert_equal(0, cli.run("foo"))
    end
  end

  it "runs setup statically" do
    test = self
    fake_gems = FakeGemsService.new
    my_gemfile_dir = gemfile_dir
    my_gemfile_path = gemfile_path

    cli.add_config_block do
      tool "foo" do
        include :bundler, setup: :static, search_dirs: my_gemfile_dir
        test.refute_nil(fake_gems.bundle_args)
        test.assert_equal(my_gemfile_path, fake_gems.bundle_args[:gemfile_path])
        to_run do
          exit(1) unless fake_gems.bundle_args
          exit(2) unless fake_gems.bundle_args[:gemfile_path] == my_gemfile_path
        end
      end
    end

    ::Toys::Utils::Gems.stub(:new, fake_gems) do
      assert_equal(0, cli.run("foo"))
    end
  end

  it "checks for illegal setup value" do
    test = self
    fake_gems = FakeGemsService.new
    my_gemfile_dir = gemfile_dir

    cli.add_config_block do
      tool "foo" do
        include :bundler, setup: :foo, search_dirs: my_gemfile_dir
        def run
          puts "Hello"
        end
      end
    end

    e = test.assert_raises(::Toys::ContextualError) do
      ::Toys::Utils::Gems.stub(:new, fake_gems) do
        cli.run("foo")
      end
    end
    assert_kind_of(::ArgumentError, e.cause)
    assert_equal("Unrecognized setup type: :foo", e.cause.message)
  end
end
