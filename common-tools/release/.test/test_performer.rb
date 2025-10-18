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
  let(:sample_release_version) { Gem::Version.new("0.99.99") }
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
    assert_equal("Docs already published for #{name} #{version}", successes[2])
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
    assert_equal("Docs already published for #{name} #{version}", successes[2])
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
end
