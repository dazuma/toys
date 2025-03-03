require_relative "helper"
require_relative "../.lib/artifact_dir"
require_relative "../.lib/component"
require_relative "../.lib/environment_utils"
require_relative "../.lib/performer"
require_relative "../.lib/repo_settings"
require_relative "../.lib/repository"
require_relative "../.lib/steps"

describe ToysReleaser::Steps do
  let(:fake_tool_context) { ToysReleaser::Tests::FakeToolContext.new(allow_passthru_exec: true) }
  let(:environment_utils) { ToysReleaser::EnvironmentUtils.new(fake_tool_context, on_error_option: :nothing) }
  let(:repo_settings) { ToysReleaser::RepoSettings.load_from_environment(environment_utils) }
  let(:repository) { ToysReleaser::Repository.new(environment_utils, repo_settings) }
  let(:toys_component) { ToysReleaser::Component.build(repo_settings, "toys", environment_utils) }
  let(:core_component) { ToysReleaser::Component.build(repo_settings, "toys-core", environment_utils) }
  let(:tools_component) { ToysReleaser::Component.build(repo_settings, "common-tools", environment_utils) }
  let(:artifact_dir) { ToysReleaser::ArtifactDir.new }
  let(:sample_release_version) { Gem::Version.new("0.99.99") }
  let(:step_name) { "my-step" }

  def make_basic_result(component, version)
    ToysReleaser::Performer::Result.new(component.name, version, true)
  end

  def make_basic_step(type, component: nil, version: nil, dry_run: true, options: {}, performer_result: nil)
    component ||= toys_component
    version ||= sample_release_version
    performer_result ||= make_basic_result(component, version)
    ToysReleaser::Steps.const_get(type).new(
      repository: repository, component: component, version: version, performer_result: performer_result,
      artifact_dir: artifact_dir, dry_run: dry_run, git_remote: "origin", name: step_name, options: options
    )
  end

  def in_component_directory(component, &block)
    ::Dir.chdir("#{fake_tool_context.context_directory}/#{component.name}", &block)
  end

  after do
    artifact_dir.cleanup
  end

  describe "Base" do
    def make_step(options)
      make_basic_step("Base", options: options)
    end

    it "gets options" do
      step = make_step({"foo" => "bar"})
      assert_equal("bar", step.option("foo"))
    end

    it "Runs a successful command" do
      fake_tool_context.stub_exec(["command_success"], output: "command was run")
      step = make_step({"pre_command" => ["command_success"]})
      step.pre_command
      assert_includes(fake_tool_context.console_output, "command was run")
    end

    it "Runs a failing command" do
      fake_tool_context.stub_exec(["command_failure"], output: "command run failed", result_code: 1)
      step = make_step({"pre_command" => ["command_failure"]})
      assert_raises(ToysReleaser::Steps::StepExit) do
        step.pre_command
      end
      assert_includes(fake_tool_context.console_output, "command run failed")
      assert_includes(fake_tool_context.console_output,
                      "Pre-build command failed: [\"command_failure\"]. Check the logs for details.")
    end
  end

  describe "Tool" do
    def make_step(tool, abort_pipeline_on_error: false)
      make_basic_step("Tool", options: {"tool" => tool, "abort_pipeline_on_error" => abort_pipeline_on_error})
    end

    it "runs a succeeding tool" do
      fake_tool_context.stub_separate_tool(["sample-tool-success"], output: "This is a sample tool.")
      step = make_step(["sample-tool-success"])
      step.run
      assert_includes(fake_tool_context.console_output, "This is a sample tool.")
    end

    it "runs a failing tool" do
      fake_tool_context.stub_separate_tool(["sample-tool-failure"], result_code: 1, output: "Tool run failed.")
      step = make_step(["sample-tool-failure"])
      assert_raises(ToysReleaser::Steps::StepExit) do
        step.run
      end
      assert_includes(fake_tool_context.console_output, "Tool run failed.")
      assert_includes(fake_tool_context.console_output,
                      "Tool failed: [\"sample-tool-failure\"]. Check the logs for details.")
    end

    it "runs a failing tool and aborts the pipeline" do
      fake_tool_context.stub_separate_tool(["sample-tool-failure"], result_code: 1, output: "Tool run failed.")
      step = make_step(["sample-tool-failure"], abort_pipeline_on_error: true)
      assert_raises(ToysReleaser::Steps::AbortingExit) do
        step.run
      end
      assert_includes(fake_tool_context.console_output, "Tool run failed.")
      assert_includes(fake_tool_context.console_output,
                      "Tool failed: [\"sample-tool-failure\"]. Check the logs for details.")
    end
  end

  describe "Command" do
    def make_step(command, abort_pipeline_on_error: false)
      make_basic_step("Command", options: {"command" => command, "abort_pipeline_on_error" => abort_pipeline_on_error})
    end

    it "runs a succeeding command" do
      fake_tool_context.stub_exec(["command-success"], output: "This is a sample command.")
      step = make_step(["command-success"])
      step.run
      assert_includes(fake_tool_context.console_output, "This is a sample command.")
    end

    it "runs a failing command" do
      fake_tool_context.stub_exec(["command-failure"], result_code: 1, output: "Command run failed.")
      step = make_step(["command-failure"])
      assert_raises(ToysReleaser::Steps::StepExit) do
        step.run
      end
      assert_includes(fake_tool_context.console_output, "Command run failed.")
      assert_includes(fake_tool_context.console_output,
                      "Command failed: [\"command-failure\"]. Check the logs for details.")
    end

    it "runs a failing command and aborts the pipeline" do
      fake_tool_context.stub_exec(["command-failure"], result_code: 1, output: "Command run failed.")
      step = make_step(["command-failure"], abort_pipeline_on_error: true)
      assert_raises(ToysReleaser::Steps::AbortingExit) do
        step.run
      end
      assert_includes(fake_tool_context.console_output, "Command run failed.")
      assert_includes(fake_tool_context.console_output,
                      "Command failed: [\"command-failure\"]. Check the logs for details.")
    end
  end

  describe "BuildGem" do
    def make_step(component)
      make_basic_step("BuildGem", component: component)
    end

    it "builds the toys gem" do
      step = make_step(toys_component)
      in_component_directory(toys_component) do
        _out, err = capture_subprocess_io do
          step.run
        end
        assert_includes(err, "Successfully built RubyGem")
      end
      dir = artifact_dir.get(step_name)
      assert(::File.file?("#{dir}/toys-#{sample_release_version}.gem"), "Expected gem file to be generated")
    end

    it "builds the toys-core gem" do
      step = make_step(core_component)
      in_component_directory(core_component) do
        _out, err = capture_subprocess_io do
          step.run
        end
        assert_includes(err, "Successfully built RubyGem")
      end
      dir = artifact_dir.get(step_name)
      assert(::File.file?("#{dir}/toys-core-#{sample_release_version}.gem"), "Expected gem file to be generated")
    end
  end

  describe "BuildYard" do
    def make_bundle_step(component)
      make_basic_step("Bundle", component: component)
    end

    def make_step(component, pre_tool: nil)
      make_basic_step("BuildYard", component: component, options: {"pre_tool" => pre_tool})
    end

    before do
      skip unless ENV["TOYS_TEST_INTEGRATION"]
      skip if ::Toys::Compat.jruby?
    end

    it "builds docs for the toys-core gem" do
      bundle_step = make_bundle_step(core_component)
      step = make_step(core_component)
      in_component_directory(core_component) do
        capture_subprocess_io do
          bundle_step.run
        end
        _out, err = capture_subprocess_io do
          step.run
        end
        assert_includes(err, "documented")
      end
      dir = artifact_dir.get(step_name)
      assert(::File.file?("#{dir}/doc/index.html"), "Expected yardocs to be generated")
    end

    it "builds docs for the toys gem with a pre-tool" do
      bundle_step = make_bundle_step(toys_component)
      step = make_step(toys_component, pre_tool: ["copy-core-docs"])
      in_component_directory(toys_component) do
        capture_subprocess_io do
          bundle_step.run
        end
        _out, err = capture_subprocess_io do
          step.run
        end
        assert_includes(err, "documented")
      end
      dir = artifact_dir.get(step_name)
      assert(::File.file?("#{dir}/doc/Toys/Core.html"), "Expected yardocs to be generated")
    end
  end

  describe "ReleaseGem" do
    let(:performer_result) { make_basic_result(toys_component, sample_release_version) }
    let(:build_step_name) { "my-build-step" }

    def make_step(dry_run: true)
      make_basic_step("ReleaseGem", component: toys_component, dry_run: dry_run, performer_result: performer_result,
                      options: {"input" => build_step_name})
    end

    def stub_version_check(exists)
      output = exists ? "toys (#{sample_release_version})\n" : "Not found"
      cmd = ["gem", "search", "toys", "--exact", "--remote", "--version", sample_release_version.to_s]
      fake_tool_context.stub_capture(cmd, output: output)
    end

    it "aborts if gem exists" do
      stub_version_check(true)
      step = make_step
      assert_raises(ToysReleaser::Steps::StepExit) do
        step.run
      end
      assert_equal(1, performer_result.successes.size)
      assert_equal("Gem already pushed for toys #{sample_release_version}", performer_result.successes.first)
    end

    it "does a dry run release" do
      stub_version_check(false)
      step = make_step(dry_run: true)
      step.run
      assert_equal(1, performer_result.successes.size)
      assert_equal("DRY RUN Rubygems push for toys #{sample_release_version}.", performer_result.successes.first)
    end

    it "does a real release" do
      stub_version_check(false)
      pkg_path = ::File.join(artifact_dir.get(build_step_name), "toys-#{sample_release_version}.gem")
      fake_tool_context.stub_exec(["gem", "push", pkg_path])
      fake_tool_context.prevent_real_exec_prefix(["gem", "push"])
      step = make_step(dry_run: false)
      step.run
      assert_equal(1, performer_result.successes.size)
      assert_equal("Rubygems push for toys #{sample_release_version}.", performer_result.successes.first)
    end

    it "fails at a release" do
      stub_version_check(false)
      pkg_path = ::File.join(artifact_dir.get(build_step_name), "toys-#{sample_release_version}.gem")
      fake_tool_context.stub_exec(["gem", "push", pkg_path], result_code: 1)
      fake_tool_context.prevent_real_exec_prefix(["gem", "push"])
      step = make_step(dry_run: false)
      assert_raises(ToysReleaser::Steps::StepExit) do
        step.run
      end
      assert_empty(performer_result.successes)
    end
  end
  
  describe "PushGhPages" do
    let(:build_step_name) { "my-build-step" }

    def make_performer_result(version)
      make_basic_result(toys_component, Gem::Version.new(version))
    end

    def make_step(version, performer_result, dry_run: true)
      make_basic_step("PushGhPages", component: toys_component, dry_run: dry_run, performer_result: performer_result,
                      version: Gem::Version.new(version), options: {"input" => build_step_name})
    end

    def make_dummy_docs
      ::Dir.chdir(artifact_dir.get(build_step_name)) do
        ::FileUtils.mkdir("doc")
        ::File.write("doc/index.html", "Hello\n")
      end
    end

    before do
      skip unless ENV["TOYS_TEST_INTEGRATION"]
    end

    it "aborts if docs exist" do
      version = "0.15.6"
      performer_result = make_performer_result(version)
      step = make_step(version, performer_result)
      assert_raises(ToysReleaser::Steps::StepExit) do
        capture_subprocess_io do
          step.run
        end
      end
      assert_equal(1, performer_result.successes.size)
      assert_equal("Docs already published for toys #{version}", performer_result.successes.first)
    end

    it "does a dry run publish" do
      version = "0.99.99"
      make_dummy_docs
      performer_result = make_performer_result(version)
      step = make_step(version, performer_result, dry_run: true)
      capture_subprocess_io do
        step.run
      end
      assert_equal(1, performer_result.successes.size)
      assert_equal("DRY RUN documentation publish for toys #{version}.", performer_result.successes.first)
      path = ::File.join(artifact_dir.get("gh-pages"), "gems", "toys", "v#{version}", "index.html")
      assert(::File.file?(path), "Expected docs to be copied into gh-pages")
      content = ::File.read(::File.join(artifact_dir.get("gh-pages"), "404.html"))
      assert_includes(content, 'version = "0.99.99";')
    end

    it "does a real publish" do
      version = "0.99.99"
      make_dummy_docs
      performer_result = make_performer_result(version)
      step = make_step(version, performer_result, dry_run: false)
      fake_tool_context.stub_exec(["git", "push", step.git_remote, "gh-pages"])
      fake_tool_context.prevent_real_exec_prefix(["git", "push"])
      capture_subprocess_io do
        step.run
      end
      assert_equal(1, performer_result.successes.size)
      assert_equal("Published documentation for toys #{version}.", performer_result.successes.first)
    end

    it "fails to publish" do
      version = "0.99.99"
      make_dummy_docs
      performer_result = make_performer_result(version)
      step = make_step(version, performer_result, dry_run: false)
      fake_tool_context.stub_exec(["git", "push", step.git_remote, "gh-pages"], result_code: 1)
      fake_tool_context.prevent_real_exec_prefix(["git", "push"])
      assert_raises(ToysReleaser::Steps::StepExit) do
        capture_subprocess_io do
          step.run
        end
      end
      assert_empty(performer_result.successes)
    end
  end

  describe "GitHubRelease" do
    let(:performer_result) { make_basic_result(toys_component, sample_release_version) }
    let(:build_step_name) { "my-build-step" }

    def make_step(dry_run: true)
      make_basic_step("GitHubRelease", component: toys_component, dry_run: dry_run, performer_result: performer_result)
    end

    def stub_version_check(exists)
      cmd = ["gh", "api", "repos/dazuma/toys/releases/tags/toys/v#{sample_release_version}",
             "-H", "Accept: application/vnd.github.v3+json"]
      result_code = exists ? 0 : 1
      fake_tool_context.stub_exec(cmd, result_code: result_code)
    end

    def stub_release_creation(result_code)
      cmd = ["gh", "api", "repos/dazuma/toys/releases", "--input", "-",
             "-H", "Accept: application/vnd.github.v3+json"]
      fake_tool_context.stub_exec(cmd, result_code: result_code)
    end

    it "aborts if tag exists" do
      stub_version_check(true)
      step = make_step
      assert_raises(ToysReleaser::Steps::StepExit) do
        step.run
      end
      assert_equal(1, performer_result.successes.size)
      assert_equal("GitHub tag toys/v#{sample_release_version} already exists.", performer_result.successes.first)
    end

    it "does a dry run release" do
      stub_version_check(false)
      step = make_step(dry_run: true)
      step.run
      assert_equal(1, performer_result.successes.size)
      assert_equal("DRY RUN GitHub tag toys/v#{sample_release_version}.", performer_result.successes.first)
    end

    it "does a real release" do
      stub_version_check(false)
      step = make_step(dry_run: false)
      stub_release_creation(0)
      fake_tool_context.prevent_real_exec_prefix(["gh", "api"])
      step.run
      assert_equal(1, performer_result.successes.size)
      assert_equal("Created release with tag toys/v#{sample_release_version} on GitHub.", performer_result.successes.first)
    end

    it "fails to do a real release" do
      stub_version_check(false)
      step = make_step(dry_run: false)
      stub_release_creation(1)
      fake_tool_context.prevent_real_exec_prefix(["gh", "api"])
      assert_raises(ToysReleaser::Steps::StepExit) do
        step.run
      end
      assert_empty(performer_result.successes)
    end
  end
end
