# frozen_string_literal: true

require "helper"
require "fileutils"
require "timeout"
require "toys/utils/gems"

describe Toys::Utils::Gems do
  let(:gems_cases_dir) { File.join(File.dirname(__dir__), "gems-cases") }
  let(:exec_service) { Toys::Utils::Exec.new }

  def setup_case(name)
    ::Bundler.with_unbundled_env do
      Dir.chdir(File.join(gems_cases_dir, name)) do
        ::Timeout.timeout(30) do
          yield
        end
      end
    end
  end

  def run_script(name = "run_test.rb", *args)
    exec_service.exec_ruby(["-I#{Toys::CORE_LIB_PATH}", name, *args],
                           out: :capture, err: :capture, in: :null)
  end

  describe "#bundle" do
    it "sets up a bundle without toys" do
      setup_case("bundle-without-toys") do
        FileUtils.rm_f("Gemfile.lock")
        result = run_script
        assert(result.success?)
        result = run_script
        assert(result.success?)
      end
    end

    it "sets up a bundle with compatible toys" do
      setup_case("bundle-with-compatible-toys") do
        FileUtils.rm_f("Gemfile.lock")
        result = run_script
        assert(result.success?)
        result = run_script
        assert(result.success?)
      end
    end

    it "fails to set up a bundle with incompatible toys" do
      setup_case("bundle-with-incompatible-toys") do
        FileUtils.rm_f("Gemfile.lock")
        result = run_script
        refute(result.success?)
        assert_match(/Toys::Utils::Gems::IncompatibleToysError/, result.captured_err)
        refute_match(/should-not-get-here/, result.captured_out)
      end
    end

    it "sets up a bundle requiring installation of a direct dependency" do
      skip if Toys::Compat.jruby?
      setup_case("bundle-without-toys") do
        FileUtils.rm_f("Gemfile.lock")
        exec_service.exec(["gem", "uninstall", "highline", "--version=2.0.2"], out: :null)
        result = run_script
        assert(result.success?)
        assert_match(/Your bundle requires additional gems\. Install\?/, result.captured_out)
        exec_service.exec(["gem", "uninstall", "highline", "--version=2.0.2"], out: :null)
        result = run_script
        assert(result.success?)
        assert_match(/Your bundle requires additional gems\. Install\?/, result.captured_out)
        result = run_script
        assert(result.success?)
        refute_match(/Your bundle requires additional gems\. Install\?/, result.captured_out)
      end
    end

    it "sets up a bundle requiring installation of a transitive dependency via a gemspec" do
      skip if Toys::Compat.jruby?
      setup_case("bundle-using-gemspec") do
        FileUtils.rm_f("Gemfile.lock")
        exec_service.exec(["gem", "uninstall", "highline", "--version=2.0.1"], out: :null)
        result = run_script
        assert(result.success?)
        assert_match(/Your bundle requires additional gems\. Install\?/, result.captured_out)
        exec_service.exec(["gem", "uninstall", "highline", "--version=2.0.1"], out: :null)
        result = run_script
        assert(result.success?)
        assert_match(/Your bundle requires additional gems\. Install\?/, result.captured_out)
        result = run_script
        assert(result.success?)
        refute_match(/Your bundle requires additional gems\. Install\?/, result.captured_out)
      end
    end
  end

  describe "#activate" do
    it "installs and activates a gem" do
      setup_case("activate-highline") do
        exec_service.exec(["gem", "uninstall", "highline", "--version=2.0.1"], out: :null)
        result = run_script
        assert(result.success?)
        assert_match(/Gem needed: .* Install\?/, result.captured_out)
        result = run_script
        assert(result.success?)
        refute_match(/Gem needed: .* Install\?/, result.captured_out)
      end
    end
  end
end
