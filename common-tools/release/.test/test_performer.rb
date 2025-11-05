require_relative "helper"
require_relative "../.lib/environment_utils"
require_relative "../.lib/performer"
require_relative "../.lib/repo_settings"
require_relative "../.lib/repository"

describe ToysReleaser::Performer do
  let(:fake_tool_context) { ToysReleaser::Tests::FakeToolContext.new(allow_passthru_exec: true) }
  let(:environment_utils) { ToysReleaser::EnvironmentUtils.new(fake_tool_context, on_error_option: :nothing) }
  let(:repo_settings) { ToysReleaser::RepoSettings.load_from_environment(environment_utils) }
  let(:repository) { ToysReleaser::Repository.new(environment_utils, repo_settings) }
  let(:performer) { ToysReleaser::Performer.new(repository, enable_prechecks: false, dry_run: true) }

  def stub_existence_checks(name, version)
    cmd = ["gem", "search", name, "--exact", "--remote", "--version", version.to_s]
    fake_tool_context.stub_capture(cmd, output: "Not found")
    cmd = ["gh", "api", "repos/dazuma/toys/releases/tags/#{name}/v#{version}",
            "-H", "Accept: application/vnd.github.v3+json"]
    fake_tool_context.stub_exec(cmd, result_code: 1)
  end

  before do
    skip unless ENV["TOYS_TEST_INTEGRATION"]
    skip if ::Toys::Compat.jruby?
  end

  it "does a dry run adhoc release of toys" do
    name = "toys"
    component = repository.component_named(name)
    version = component.current_changelog_version
    stub_existence_checks(name, version)
    capture_subprocess_io do
      performer.perform_adhoc_release(name)
    end
    assert_equal(1, performer.component_results.size)
    successes = performer.component_results.first.successes
    assert_equal(3, successes.size)
    assert_equal("DRY RUN GitHub tag #{name}/v#{version}.", successes[0])
    assert_equal("DRY RUN Rubygems push for #{name} #{version}.", successes[1])
    assert_includes(successes[2], "published for #{name} #{version}")
  end

  it "does a dry run adhoc release of toys-core" do
    name = "toys-core"
    component = repository.component_named(name)
    version = component.current_changelog_version
    stub_existence_checks(name, version)
    capture_subprocess_io do
      performer.perform_adhoc_release(name)
    end
    assert_equal(1, performer.component_results.size)
    successes = performer.component_results.first.successes
    assert_equal(3, successes.size)
    assert_equal("DRY RUN GitHub tag #{name}/v#{version}.", successes[0])
    assert_equal("DRY RUN Rubygems push for #{name} #{version}.", successes[1])
    assert_includes(successes[2], "published for #{name} #{version}")
  end

  it "does a dry run adhoc release of common-tools" do
    name = "common-tools"
    component = repository.component_named(name)
    version = component.current_changelog_version
    stub_existence_checks(name, version)
    capture_subprocess_io do
      performer.perform_adhoc_release(name)
    end
    assert_equal(1, performer.component_results.size)
    successes = performer.component_results.first.successes
    assert_equal(1, successes.size)
    assert_equal("DRY RUN GitHub tag #{name}/v#{version}.", successes[0])
  end

  it "builds a report" do
    # Silence output from constructing and prevalidating the performer
    capture_subprocess_io { performer }
    performer.init_result.successes << "Init success"
    performer.init_result.errors << "Init error 1"
    performer.init_result.errors << "Init error 2"
    toys_version = repository.component_named("toys").current_changelog_version
    toys_result = ToysReleaser::Performer::Result.new("toys", toys_version)
    toys_result.successes << "Toys success"
    core_version = repository.component_named("toys-core").current_changelog_version
    core_result = ToysReleaser::Performer::Result.new("toys-core", core_version)
    core_result.successes << "Toys-Core success"
    core_result.errors << "Toys-Core error"
    performer.component_results << core_result << toys_result
    report = performer.build_report_text
    assert_includes(report, "**Release job completed with errors.**")
    assert_includes(report, "\n\n* ERROR: Init error 1\n* ERROR: Init error 2\n* Init success")
    assert_includes(report, "\n\n* ERROR: Toys-Core error\n* Toys-Core success")
    assert_includes(report, "\n\n* Toys success")
    if ::ENV["GITHUB_RUN_ID"]
      assert_match(%r{\n\* Run logs: https://github\.com/dazuma/toys/actions/runs/\d+\n}, report)
    end
  end
end
