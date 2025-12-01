# frozen_string_literal: true

require_relative "helper"

describe Toys::Release::Steps do
  let(:fake_tool_context) { Toys::Release::Tests::FakeToolContext.new(allow_passthru_exec: true) }
  let(:environment_utils) { Toys::Release::EnvironmentUtils.new(fake_tool_context, on_error_option: :nothing) }
  let(:repo_settings) { Toys::Release::RepoSettings.load_from_environment(environment_utils) }
  let(:repository) { Toys::Release::Repository.new(environment_utils, repo_settings) }
  let(:toys_component) { Toys::Release::Component.new(repo_settings, "toys", environment_utils) }
  let(:core_component) { Toys::Release::Component.new(repo_settings, "toys-core", environment_utils) }
  let(:tools_component) { Toys::Release::Component.new(repo_settings, "common-tools", environment_utils) }
  let(:artifact_dir) { Toys::Release::ArtifactDir.new }
  let(:sample_release_version) { Gem::Version.new("0.99.99") }
  let(:repo_root_dir) { File.dirname(File.dirname(File.dirname(__dir__))) }

  def make_basic_result(component, version)
    Toys::Release::Performer::Result.new(component.name, version)
  end

  def make_pipeline(component: nil, version: nil, dry_run: true, performer_result: nil)
    component ||= toys_component
    version ||= sample_release_version
    performer_result ||= make_basic_result(component, version)
    Toys::Release::Pipeline.new(
      repository: repository, component: component, version: version, performer_result: performer_result,
      artifact_dir: artifact_dir, dry_run: dry_run, git_remote: "origin"
    )
  end

  def in_component_directory(component, &block)
    ::Dir.chdir(::File.join(fake_tool_context.repo_root_directory, component.name), &block)
  end

  after do
    artifact_dir.cleanup
  end

  describe "TOOL" do
    def make_context(tool, abort_pipeline_on_error: false)
      settings = Toys::Release::StepSettings.new(
        {"name" => "tool", "tool" => tool, "abort_pipeline_on_error" => abort_pipeline_on_error}, []
      )
      Toys::Release::Pipeline::StepContext.new(make_pipeline, settings)
    end

    it "runs a succeeding tool" do
      fake_tool_context.stub_separate_tool(["sample-tool-success"], output: "This is a sample tool.")
      Toys::Release::Steps::TOOL.run(make_context(["sample-tool-success"]))
      assert_includes(fake_tool_context.console_output, "This is a sample tool.")
    end

    it "runs a failing tool" do
      fake_tool_context.stub_separate_tool(["sample-tool-failure"], result_code: 1, output: "Tool run failed.")
      assert_raises(Toys::Release::Pipeline::PipelineExit) do
        Toys::Release::Steps::TOOL.run(make_context(["sample-tool-failure"]))
      end
      assert_includes(fake_tool_context.console_output, "Tool run failed.")
      assert_includes(fake_tool_context.console_output,
                      "Tool failed: [\"sample-tool-failure\"]. Check the logs for details.")
    end
  end

  describe "COMMAND" do
    def make_context(command, abort_pipeline_on_error: false)
      settings = Toys::Release::StepSettings.new(
        {"name" => "command", "command" => command, "abort_pipeline_on_error" => abort_pipeline_on_error}, []
      )
      Toys::Release::Pipeline::StepContext.new(make_pipeline, settings)
    end

    it "runs a succeeding command" do
      fake_tool_context.stub_exec(["command-success"], output: "This is a sample command.")
      Toys::Release::Steps::COMMAND.run(make_context(["command-success"]))
      assert_includes(fake_tool_context.console_output, "This is a sample command.")
    end

    it "runs a failing command" do
      fake_tool_context.stub_exec(["command-failure"], result_code: 1, output: "Command run failed.")
      assert_raises(Toys::Release::Pipeline::PipelineExit) do
        Toys::Release::Steps::COMMAND.run(make_context(["command-failure"]))
      end
      assert_includes(fake_tool_context.console_output, "Command run failed.")
      assert_includes(fake_tool_context.console_output,
                      "Command failed: [\"command-failure\"]. Check the logs for details.")
    end
  end

  describe "BUNDLE" do
    let(:step_settings) { ::Toys::Release::StepSettings.new({"name" => "bundle"}, []) }
    let(:step_context) { ::Toys::Release::Pipeline::StepContext.new(make_pipeline, step_settings) }

    it "runs bundler" do
      fake_tool_context.stub_exec(["bundle", "install"], output: "Bundle installed.") do
        ::FileUtils.touch("Gemfile.lock")
      end
      in_component_directory(toys_component) do
        ::Toys::Release::Steps::BUNDLE.run(step_context)
      end
      assert_includes(fake_tool_context.console_output, "Bundle installed.")
      lockfile_path = ::File.join(artifact_dir.output("bundle"), "Gemfile.lock")
      assert(::File.file?(lockfile_path), "Expected lockfile to be generated")
    end
  end

  describe "BUILD_GEM" do
    def make_context(component)
      settings = ::Toys::Release::StepSettings.new({"name" => "build_gem"}, [])
      ::Toys::Release::Pipeline::StepContext.new(make_pipeline(component: component), settings)
    end

    it "builds the toys gem" do
      step_context = make_context(toys_component)
      in_component_directory(toys_component) do
        _out, err = capture_subprocess_io do
          ::Toys::Release::Steps::BUILD_GEM.run(step_context)
        end
        assert_includes(err, "Successfully built RubyGem")
      end
      pkg_path = ::File.join(step_context.output_dir, "pkg", "toys-#{sample_release_version}.gem")
      assert(::File.file?(pkg_path), "Expected gem file to be generated")
    end

    it "builds the toys-core gem" do
      step_context = make_context(core_component)
      in_component_directory(core_component) do
        _out, err = capture_subprocess_io do
          ::Toys::Release::Steps::BUILD_GEM.run(step_context)
        end
        assert_includes(err, "Successfully built RubyGem")
      end
      pkg_path = ::File.join(step_context.output_dir, "pkg", "toys-core-#{sample_release_version}.gem")
      assert(::File.file?(pkg_path), "Expected gem file to be generated")
    end
  end

  describe "BUILD_YARD" do
    def make_build_context(component, uses_gems)
      settings = ::Toys::Release::StepSettings.new({"name" => "build_yard", "uses_gems" => uses_gems}, [])
      ::Toys::Release::Pipeline::StepContext.new(make_pipeline(component: component), settings)
    end

    before do
      skip unless ENV["TOYS_TEST_INTEGRATION"]
      skip if ::Toys::Compat.jruby?
    end

    it "sets dependencies in bundle mode" do
      step_context = make_build_context(core_component, nil)
      assert_equal(["bundle"], ::Toys::Release::Steps::BUILD_YARD.dependencies(step_context))
    end

    it "sets dependencies in uses_gems mode" do
      step_context = make_build_context(core_component, "redcarpet")
      assert_empty(::Toys::Release::Steps::BUILD_YARD.dependencies(step_context))
    end

    it "builds docs for the toys-core gem in uses_gems mode" do
      step_context = make_build_context(core_component, "redcarpet")
      in_component_directory(core_component) do
        _out, err = capture_subprocess_io do
          ::Toys::Release::Steps::BUILD_YARD.run(step_context)
        end
        assert_includes(err, "documented")
        assert_includes(err, "Loading gems explicitly: \"redcarpet\"")
      end
      path = ::File.join(step_context.output_dir, "doc", "Toys", "Core.html")
      assert(::File.file?(path), "Expected yardocs to be generated")
    end

    it "builds docs for the toys gem in bundle mode" do
      step_context = make_build_context(toys_component, nil)
      in_component_directory(toys_component) do
        capture_subprocess_io do
          toys_component.bundle
        end
        _out, err = capture_subprocess_io do
          ::Toys::Release::Steps::BUILD_YARD.run(step_context)
        end
        assert_includes(err, "documented")
        assert_includes(err, "Running with bundler")
      end
      path = ::File.join(step_context.output_dir, "doc", "Toys", "StandardCLI.html")
      assert(::File.file?(path), "Expected yardocs to be generated")
    end
  end

  describe "RELEASE_GEM" do
    let(:performer_result) { make_basic_result(toys_component, sample_release_version) }
    let(:pkg_dir) { ::File.join(artifact_dir.output("build_gem"), "pkg") }
    let(:pkg_path) { ::File.join(pkg_dir, "toys-#{sample_release_version}.gem") }

    def make_context(dry_run: true, source: nil)
      settings_hash = {"name" => "release_gem"}
      settings_hash["source"] = source if source
      settings = ::Toys::Release::StepSettings.new(settings_hash, [])
      pipeline = make_pipeline(dry_run: dry_run, performer_result: performer_result)
      ::Toys::Release::Pipeline::StepContext.new(pipeline, settings)
    end

    def stub_version_check(exists)
      output = exists ? "toys (#{sample_release_version})\n" : "Not found"
      cmd = ["gem", "search", "toys", "--exact", "--remote", "--version", sample_release_version.to_s]
      fake_tool_context.stub_capture(cmd, output: output)
    end

    def make_dummy_pkg
      ::FileUtils.mkdir_p(pkg_dir)
      ::File.write(pkg_path, "hello")
    end

    before do
      fake_tool_context.prevent_real_exec_prefix(["gem", "push"])
    end

    it "is primary if run from where there is a gemspec" do
      Dir.chdir(File.join(repo_root_dir, "toys")) do
        assert(::Toys::Release::Steps::RELEASE_GEM.primary?(make_context))
      end
    end

    it "is not primary if there is no gemspec" do
      Dir.chdir(File.join(repo_root_dir, "toys-core")) do
        refute(::Toys::Release::Steps::RELEASE_GEM.primary?(make_context))
      end
    end

    it "has a default dependency" do
      assert_equal(["build_gem"], ::Toys::Release::Steps::RELEASE_GEM.dependencies(make_context))
    end

    it "sets the dependency from the source" do
      step_context = make_context(source: "custom_build")
      assert_equal(["custom_build"], ::Toys::Release::Steps::RELEASE_GEM.dependencies(step_context))
    end

    it "aborts if gem exists" do
      stub_version_check(true)
      step_context = make_context(dry_run: true)
      assert_raises(Toys::Release::Pipeline::StepExit) do
        ::Toys::Release::Steps::RELEASE_GEM.run(step_context)
      end
      assert_equal(1, performer_result.successes.size)
      assert_equal("Gem already pushed for toys #{sample_release_version}", performer_result.successes.first)
    end

    it "aborts dry run if the package file cannot be found" do
      stub_version_check(false)
      step_context = make_context(dry_run: true)
      assert_raises(Toys::Release::Pipeline::PipelineExit) do
        ::Toys::Release::Steps::RELEASE_GEM.run(step_context)
      end
      assert_empty(performer_result.successes)
    end

    it "does a dry run release" do
      stub_version_check(false)
      make_dummy_pkg
      step_context = make_context(dry_run: true)
      ::Toys::Release::Steps::RELEASE_GEM.run(step_context)
      assert_equal(1, performer_result.successes.size)
      assert_equal("DRY RUN Rubygems push for toys #{sample_release_version}.", performer_result.successes.first)
    end

    it "does a real release" do
      stub_version_check(false)
      make_dummy_pkg
      fake_tool_context.stub_exec(["gem", "push", pkg_path])
      step_context = make_context(dry_run: false)
      ::Toys::Release::Steps::RELEASE_GEM.run(step_context)
      assert_equal(1, performer_result.successes.size)
      assert_equal("Rubygems push for toys #{sample_release_version}.", performer_result.successes.first)
    end

    it "fails at a release" do
      stub_version_check(false)
      make_dummy_pkg
      fake_tool_context.stub_exec(["gem", "push", pkg_path], result_code: 1)
      step_context = make_context(dry_run: false)
      assert_raises(Toys::Release::Pipeline::PipelineExit) do
        ::Toys::Release::Steps::RELEASE_GEM.run(step_context)
      end
      assert_empty(performer_result.successes)
    end
  end

  describe "PUSH_GH_PAGES" do
    let(:unreleased_version) { "0.99.99" }
    let(:released_version) { "0.15.6" }

    def make_context(version: nil, dry_run: true, source: nil)
      version = Gem::Version.new(version || unreleased_version)
      @performer_result = make_basic_result(toys_component, version)
      settings_hash = {"name" => "push_gh_pages"}
      settings_hash["source"] = source if source
      settings = ::Toys::Release::StepSettings.new(settings_hash, [])
      pipeline = make_pipeline(dry_run: dry_run, performer_result: @performer_result, version: version)
      ::Toys::Release::Pipeline::StepContext.new(pipeline, settings)
    end

    def make_dummy_docs
      ::Dir.chdir(artifact_dir.output("build_yard")) do
        ::FileUtils.mkdir("doc")
        ::File.write("doc/index.html", "Hello\n")
      end
    end

    before do
      skip unless ENV["TOYS_TEST_INTEGRATION"]
      fake_tool_context.prevent_real_exec_prefix(["git", "push"])
    end

    it "is primary if gh pages is enabled" do
      assert(::Toys::Release::Steps::PUSH_GH_PAGES.primary?(make_context))
    end

    it "has a default dependency" do
      assert_equal(["build_yard"], ::Toys::Release::Steps::PUSH_GH_PAGES.dependencies(make_context))
    end

    it "sets the dependency from the source" do
      step_context = make_context(source: "custom_build")
      assert_equal(["custom_build"], ::Toys::Release::Steps::PUSH_GH_PAGES.dependencies(step_context))
    end

    it "aborts if docs exist" do
      make_dummy_docs
      step_context = make_context(version: released_version)
      assert_raises(Toys::Release::Pipeline::StepExit) do
        capture_subprocess_io do
          ::Toys::Release::Steps::PUSH_GH_PAGES.run(step_context)
        end
      end
      assert_equal(1, @performer_result.successes.size)
      assert_equal("Docs already published for toys #{released_version}", @performer_result.successes.first)
    end

    it "does a dry run publish" do
      make_dummy_docs
      step_context = make_context(dry_run: true)
      capture_subprocess_io do
        ::Toys::Release::Steps::PUSH_GH_PAGES.run(step_context)
      end
      assert_equal(1, @performer_result.successes.size)
      assert_equal("DRY RUN documentation published for toys #{unreleased_version}.", @performer_result.successes.first)
      path = ::File.join(step_context.temp_dir, "gems", "toys", "v#{unreleased_version}", "index.html")
      assert(::File.file?(path), "Expected docs to be copied into gh-pages")
      content = ::File.read(::File.join(step_context.temp_dir, "404.html"))
      assert_includes(content, "version = #{unreleased_version.inspect};")
    end

    it "does a real publish" do
      make_dummy_docs
      step_context = make_context(dry_run: false)
      fake_tool_context.stub_exec(["git", "push", "origin", "gh-pages"])
      capture_subprocess_io do
        ::Toys::Release::Steps::PUSH_GH_PAGES.run(step_context)
      end
      assert_equal(1, @performer_result.successes.size)
      assert_equal("Published documentation for toys #{unreleased_version}.", @performer_result.successes.first)
    end

    it "fails to publish" do
      make_dummy_docs
      step_context = make_context(dry_run: false)
      fake_tool_context.stub_exec(["git", "push", "origin", "gh-pages"], result_code: 1)
      assert_raises(Toys::Release::Pipeline::PipelineExit) do
        capture_subprocess_io do
          ::Toys::Release::Steps::PUSH_GH_PAGES.run(step_context)
        end
      end
      assert_empty(@performer_result.successes)
    end
  end

  describe "RELEASE_GITHUB" do
    let(:performer_result) { make_basic_result(toys_component, sample_release_version) }

    def make_context(dry_run: true)
      settings = ::Toys::Release::StepSettings.new({"name" => "github_release"}, [])
      pipeline = make_pipeline(dry_run: dry_run, performer_result: performer_result)
      ::Toys::Release::Pipeline::StepContext.new(pipeline, settings)
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

    before do
      fake_tool_context.prevent_real_exec_prefix(["gh", "api"])
    end

    it "is primary" do
      assert(::Toys::Release::Steps::RELEASE_GITHUB.primary?(make_context))
    end

    it "aborts if tag exists" do
      stub_version_check(true)
      step_context = make_context(dry_run: true)
      assert_raises(Toys::Release::Pipeline::StepExit) do
        ::Toys::Release::Steps::RELEASE_GITHUB.run(step_context)
      end
      assert_equal(1, performer_result.successes.size)
      assert_equal("GitHub tag toys/v#{sample_release_version} already exists.", performer_result.successes.first)
    end

    it "does a dry run release" do
      stub_version_check(false)
      step_context = make_context(dry_run: true)
      ::Toys::Release::Steps::RELEASE_GITHUB.run(step_context)
      assert_equal(1, performer_result.successes.size)
      assert_equal("DRY RUN GitHub tag toys/v#{sample_release_version}.", performer_result.successes.first)
    end

    it "does a real release" do
      stub_version_check(false)
      step_context = make_context(dry_run: false)
      stub_release_creation(0)
      ::Toys::Release::Steps::RELEASE_GITHUB.run(step_context)
      assert_equal(1, performer_result.successes.size)
      assert_equal("Created release with tag toys/v#{sample_release_version} on GitHub.",
                   performer_result.successes.first)
    end

    it "fails to do a real release" do
      stub_version_check(false)
      step_context = make_context(dry_run: false)
      stub_release_creation(1)
      assert_raises(Toys::Release::Pipeline::PipelineExit) do
        ::Toys::Release::Steps::RELEASE_GITHUB.run(step_context)
      end
      assert_empty(performer_result.successes)
    end
  end
end
