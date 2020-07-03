# frozen_string_literal: true

require "helper"
require "fileutils"
require "English"

require "bundler"
require "toys/utils/exec"

describe "toys-core" do
  let(:exec) { Toys::Utils::Exec.new(out: :capture, err: :null) }

  def capture(cmd, env = {})
    result = exec.exec(cmd, env: env)
    assert(result.success?, "Command failed: #{cmd}")
    result.captured_out
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
      capture(["gem", "build", "toys-core-simple-example.gemspec"])
      FileUtils.mv("toys-core-simple-example-0.0.1.gem", simple_gem_pkg)
    end
    Dir.chdir(multi_file_example_dir) do
      capture(["gem", "build", "toys-core-multi-file-example.gemspec"])
      FileUtils.mv("toys-core-multi-file-example-0.0.1.gem", multi_file_gem_pkg)
    end
    capture(["gem", "install", "-i", gems_dir, "-n", bin_dir, simple_gem_pkg])
    capture(["gem", "install", "-i", gems_dir, "-n", bin_dir, multi_file_gem_pkg])

    Bundler.with_unbundled_env do
      output = capture(["#{bin_dir}/toys-core-simple-example", "--whom=Toys"],
                       { "GEM_HOME" => gems_dir })
      assert_equal("Hello, Toys!\n", output)
      output = capture(["#{bin_dir}/toys-core-multi-file-example", "greet", "--whom=Toys"],
                       { "GEM_HOME" => gems_dir })
      assert_equal("Hello, Toys!\n", output)
      Dir.chdir(tmp_dir) do
        output = capture(["#{bin_dir}/toys-core-multi-file-example", "new-repo", "myrepo"],
                         { "GEM_HOME" => gems_dir })
        assert_match(/Created repo in myrepo/, output)
        assert(File.directory?("myrepo/.git"))
      end
    end

    FileUtils.rm_rf(tmp_dir)
  end
end
