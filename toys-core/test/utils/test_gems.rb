# frozen_string_literal: true

require "helper"
require "fileutils"
require "timeout"
require "toys/utils/exec"
require "toys/utils/gems"

describe Toys::Utils::Gems do
  let(:gem_base_dir) { File.dirname(File.dirname(__dir__)) }
  let(:gems_cases_dir) { File.join(gem_base_dir, "test-data", "gems-cases") }
  let(:exec_service) { Toys::Utils::Exec.new }

  def setup_case(name, tmp_vendor: true, timeout: 60, &block)
    skip unless ::ENV["TOYS_TEST_INTEGRATION"]
    Bundler.with_unbundled_env do
      Dir.chdir(File.join(gems_cases_dir, name)) do
        old_path = ENV["BUNDLE_PATH"]
        if tmp_vendor
          ENV["BUNDLE_PATH"] = "tmp/vendor"
          FileUtils.rm_rf("tmp/vendor")
        end
        begin
          Timeout.timeout(timeout, &block)
        ensure
          if tmp_vendor
            ENV["BUNDLE_PATH"] = old_path
            FileUtils.rm_rf("tmp/vendor")
          end
        end
      end
    end
  end

  def run_script(name = "run_test.rb", *args)
    exec_service.exec_ruby(["-I#{Toys::CORE_LIB_PATH}", name, *args],
                           out: :capture, err: :capture, in: :null)
  end

  describe "#bundle" do
    let(:multi_test_clean_files) {
      ["Gemfile", "gems.rb", ".gems.rb", "Gemfile.lock", "gems.locked", ".gems.rb.lock"]
    }

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
      skip # TEMP
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

    it "sets up a bundle installing to a local directory" do
      setup_case("bundle-with-vendored-path", tmp_vendor: false) do
        FileUtils.rm_f("Gemfile.lock")
        FileUtils.rm_rf("vendor")
        result = run_script
        assert(result.success?)
        result = run_script
        assert(result.success?)
      end
    end

    it "preserves the original Gemfile.lock" do
      setup_case("bundle-without-toys", timeout: 120) do
        exec_service.exec(["bundle", "install"], out: :null, err: :null)
        FileUtils.cp("Gemfile.lock.orig", "Gemfile.lock")
        result = run_script
        assert(result.success?)
        cur_lockfile = File.read("Gemfile.lock")
        orig_lockfile = File.read("Gemfile.lock.orig")
        assert_equal(orig_lockfile, cur_lockfile)
      end
    end

    def clean_files_for_multi_tests
      files = ["Gemfile", "gems.rb", ".gems.rb", "Gemfile.lock", "gems.locked", ".gems.rb.lock"]
      files.each { |file| FileUtils.rm_f(file) }
    end

    it "chooses gems.rb over Gemfile" do
      setup_case("bundle-with-multiple-gemfiles") do
        clean_files_for_multi_tests
        FileUtils.cp("gemfile1.rb", "gems.rb")
        FileUtils.cp("gemfile2.rb", "Gemfile")
        result = run_script
        assert(result.success?)
      end
      setup_case("bundle-with-multiple-gemfiles") do
        clean_files_for_multi_tests
        FileUtils.cp("gemfile2.rb", "gems.rb")
        FileUtils.cp("gemfile1.rb", "Gemfile")
        result = run_script
        refute(result.success?)
      end
    end

    it "chooses .gems.rb over gems.rb" do
      setup_case("bundle-with-multiple-gemfiles") do
        clean_files_for_multi_tests
        FileUtils.cp("gemfile1.rb", ".gems.rb")
        FileUtils.cp("gemfile2.rb", "gems.rb")
        result = run_script
        assert(result.success?)
      end
      setup_case("bundle-with-multiple-gemfiles") do
        clean_files_for_multi_tests
        FileUtils.cp("gemfile2.rb", ".gems.rb")
        FileUtils.cp("gemfile1.rb", "gems.rb")
        result = run_script
        refute(result.success?)
      end
    end

    it "sets up a bundle requiring installation of a direct dependency" do
      skip if Toys::Compat.jruby? || Toys::Compat.truffleruby?
      skip if exec_service.capture(["gem", "list", "highline"]).include?("2.0.2")
      setup_case("bundle-without-toys") do
        FileUtils.rm_f("Gemfile.lock")
        result = run_script
        assert(result.success?)
        assert_match(/Your bundle requires additional gems\. Install\?/, result.captured_out)
        assert_match(/Bundle (complete|updated)!/, result.captured_out)
        FileUtils.rm_rf("tmp/vendor")
        result = run_script
        assert(result.success?)
        assert_match(/Your bundle requires additional gems\. Install\?/, result.captured_out)
        assert_match(/Bundle (complete|updated)!/, result.captured_out)
        result = run_script
        assert(result.success?)
        refute_match(/Your bundle requires additional gems\. Install\?/, result.captured_out)
      end
    end

    it "sets up a bundle requiring installation of a transitive dependency via a gemspec" do
      skip if Toys::Compat.jruby? || Toys::Compat.truffleruby?
      skip if exec_service.capture(["gem", "list", "highline"]).include?("2.0.1")
      setup_case("bundle-using-gemspec") do
        result = run_script
        assert(result.success?)
        assert_match(/Your bundle requires additional gems\. Install\?/, result.captured_out)
        assert_match(/Bundle (complete|updated)!/, result.captured_out)
        FileUtils.rm_rf("tmp/vendor")
        result = run_script
        assert(result.success?)
        assert_match(/Your bundle requires additional gems\. Install\?/, result.captured_out)
        assert_match(/Bundle (complete|updated)!/, result.captured_out)
        result = run_script
        assert(result.success?)
        refute_match(/Your bundle requires additional gems\. Install\?/, result.captured_out)
      end
    end

    it "updates the bundle if install fails due to conflicts" do
      skip if Toys::Compat.jruby? || Toys::Compat.truffleruby?
      # Problem installing jaro_winkler on Mac Ruby 3.4
      skip if Toys::Compat.macos? && Toys::Compat::RUBY_VERSION_CODE >= 30_400
      skip if exec_service.capture(["gem", "list", "rubocop"]).include?("0.81.0")
      setup_case("bundle-update-required") do
        FileUtils.rm_f("Gemfile.lock")
        FileUtils.cp("Gemfile.lock.orig", "Gemfile.lock")
        result = run_script
        assert(result.success?)
        assert_match(/Your bundle requires additional gems\. Install\?/, result.captured_out)
        result = run_script
        assert(result.success?)
        refute_match(/Your bundle requires additional gems\. Install\?/, result.captured_out)
      end
    end

    it "preserves the versions of default gems" do
      skip if Toys::Compat.jruby? || Toys::Compat.truffleruby?
      setup_case("bundle-with-default-gems") do
        result = run_script
        assert(result.success?)
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
