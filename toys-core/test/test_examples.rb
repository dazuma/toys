# frozen_string_literal: true

require "helper"
require "fileutils"
require "English"

require "bundler"
require "toys/utils/exec"

describe "toys-core" do
  # Version used for the temporary local build of toys-core. The examples are
  # built against this version so they are tested against the current local
  # code rather than against a released toys-core gem.
  let(:local_core_version) { "0.0.1" }

  let(:exec) { Toys::Utils::Exec.new(out: :capture, err: :capture) }

  def capture(cmd, env = {})
    result = exec.exec(cmd, env: env)
    unless result.success?
      flunk("Command failed: #{cmd}\nOut:\n#{result.captured_out}\nErr:\n#{result.captured_err}")
    end
    result.captured_out
  end

  # Builds the local toys-core source into a gem with version
  # local_core_version, and moves the result to the given path.
  def build_core_gem(core_dir, gem_pkg)
    script = <<~RUBY
      require "rubygems/package"
      spec = ::Gem::Specification.load("toys-core.gemspec")
      spec.version = "#{local_core_version}"
      spec.metadata = {}
      ::Gem::Package.build(spec)
    RUBY
    Dir.chdir(core_dir) do
      capture([::Gem.ruby, "-e", script])
      FileUtils.mv("toys-core-#{local_core_version}.gem", gem_pkg)
    end
  end

  # Copies an example into the given staging directory, pins its toys-core
  # dependency to the locally built version, builds the gem, and moves the
  # result to the given path.
  def build_example_gem(example_dir, staging_dir, gem_pkg)
    build_dir = File.join(staging_dir, File.basename(example_dir))
    FileUtils.cp_r(example_dir, build_dir)
    gemspec_path = Dir.glob(File.join(build_dir, "*.gemspec")).first
    content = File.read(gemspec_path)
    modified = content.sub(/^(\s*spec\.add_dependency "toys-core").*$/,
                           "\\1, \"= #{local_core_version}\"")
    refute_equal(content, modified, "Unable to find toys-core dependency in #{gemspec_path}")
    File.write(gemspec_path, modified)
    Dir.chdir(build_dir) do
      capture(["gem", "build", File.basename(gemspec_path)])
      FileUtils.mv(Dir.glob("*.gem").first, gem_pkg)
    end
  end

  it "builds gems and runs examples" do
    skip "Skipped integration test" unless ENV["TOYS_TEST_INTEGRATION"]

    core_dir = File.dirname(__dir__)
    tmp_dir = File.join(core_dir, "tmp")
    gems_dir = File.join(tmp_dir, "gems")
    bin_dir = File.join(tmp_dir, "bin")
    pkg_dir = File.join(tmp_dir, "pkg")
    staging_dir = File.join(tmp_dir, "staging")
    core_gem_pkg = File.join(pkg_dir, "toys-core.gem")
    simple_gem_pkg = File.join(pkg_dir, "simple.gem")
    multi_file_gem_pkg = File.join(pkg_dir, "multi-file.gem")
    examples_dir = File.join(core_dir, "examples")
    simple_example_dir = File.join(examples_dir, "simple-gem")
    multi_file_example_dir = File.join(examples_dir, "multi-file-gem")

    FileUtils.rm_rf(tmp_dir)
    FileUtils.mkdir_p(gems_dir)
    FileUtils.mkdir_p(bin_dir)
    FileUtils.mkdir_p(pkg_dir)
    FileUtils.mkdir_p(staging_dir)

    # All gems, including the local build of toys-core, are installed into
    # gems_dir, and are removed along with the rest of tmp_dir at the end.
    gem_env = { "GEM_HOME" => gems_dir }
    Bundler.with_unbundled_env do
      build_core_gem(core_dir, core_gem_pkg)
      capture(["gem", "install", "-n", bin_dir, "--no-document", core_gem_pkg], gem_env)

      build_example_gem(simple_example_dir, staging_dir, simple_gem_pkg)
      build_example_gem(multi_file_example_dir, staging_dir, multi_file_gem_pkg)
      capture(["gem", "install", "-n", bin_dir, "--no-document", simple_gem_pkg], gem_env)
      capture(["gem", "install", "-n", bin_dir, "--no-document", multi_file_gem_pkg], gem_env)

      output = capture(["#{bin_dir}/toys-core-simple-example", "--whom=Toys"], gem_env)
      assert_equal("Hello, Toys!\n", output)
      output = capture(["#{bin_dir}/toys-core-multi-file-example", "greet", "--whom=Toys"],
                       gem_env)
      assert_equal("Hello, Toys!\n", output)
      Dir.chdir(tmp_dir) do
        output = capture(["#{bin_dir}/toys-core-multi-file-example", "new-repo", "myrepo"],
                         gem_env)
        assert_match(/Created repo in myrepo/, output)
        assert(File.directory?("myrepo/.git"))
      end
    end

    FileUtils.rm_rf(tmp_dir)
  end
end
