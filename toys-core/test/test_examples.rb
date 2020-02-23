# frozen_string_literal: true

require "helper"
require "fileutils"
require "English"

require "bundler"

describe "toys-core" do
  def assert_succeeds(cmd)
    system cmd
    assert($CHILD_STATUS.success?, "Command failed: #{cmd}")
  end

  it "builds gems and runs examples" do
    core_dir = File.dirname(__dir__)
    tmp_dir = File.join(core_dir, "tmp")
    gems_dir = File.join(tmp_dir, "gems")
    bin_dir = File.join(tmp_dir, "bin")
    pkg_dir = File.join(tmp_dir, "pkg")
    simple_gem_pkg = File.join(pkg_dir, "simple.gem")
    multi_file_gem_pkg = File.join(pkg_dir, "multi-file.gem")
    examples_dir = File.join(core_dir, "examples")
    simple_example_dir = File.join(examples_dir, "simple-gem")
    multi_file_example_dir = File.join(examples_dir, "multi-file-gem")

    FileUtils.rm_rf(tmp_dir)
    FileUtils.mkdir_p(gems_dir)
    FileUtils.mkdir_p(bin_dir)
    FileUtils.mkdir_p(pkg_dir)

    Dir.chdir(simple_example_dir) do
      assert_succeeds("gem build toys-core-simple-example.gemspec >/dev/null 2>&1")
      FileUtils.mv("toys-core-simple-example-0.0.1.gem", simple_gem_pkg)
    end
    Dir.chdir(multi_file_example_dir) do
      assert_succeeds("gem build toys-core-multi-file-example.gemspec >/dev/null 2>&1")
      FileUtils.mv("toys-core-multi-file-example-0.0.1.gem", multi_file_gem_pkg)
    end
    assert_succeeds("gem install -i #{gems_dir} -n #{bin_dir} #{simple_gem_pkg} >/dev/null")
    assert_succeeds("gem install -i #{gems_dir} -n #{bin_dir} #{multi_file_gem_pkg} >/dev/null")

    Bundler.with_unbundled_env do
      assert_equal("Hello, Toys!\n",
                   `GEM_HOME=#{gems_dir} #{bin_dir}/toys-core-simple-example --whom=Toys`)
      assert_equal("Hello, Toys!\n",
                   `GEM_HOME=#{gems_dir} #{bin_dir}/toys-core-multi-file-example greet --whom=Toys`)
      Dir.chdir(tmp_dir) do
        assert_match(/Created repo in myrepo/,
                     `GEM_HOME=#{gems_dir} #{bin_dir}/toys-core-multi-file-example new-repo myrepo`)
        assert(File.directory?("myrepo/.git"))
      end
    end

    FileUtils.rm_rf(tmp_dir)
  end
end
