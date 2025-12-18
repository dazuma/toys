# frozen_string_literal: true

require_relative "helper"

describe Toys::Release::Pipeline do
  let(:component_name) { "toys-release" }
  let(:fake_tool_context) { Toys::Release::Tests::FakeToolContext.new(allow_passthru_exec: true) }
  let(:environment_utils) { Toys::Release::EnvironmentUtils.new(fake_tool_context, on_error_option: :nothing) }
  let(:repo_settings) { Toys::Release::RepoSettings.load_from_environment(environment_utils) }
  let(:repository) { Toys::Release::Repository.new(environment_utils, repo_settings) }
  let(:component) { Toys::Release::Component.new(repo_settings, component_name, environment_utils) }
  let(:repo_root_dir) { File.dirname(File.dirname(File.dirname(__dir__))) }
  let(:component_dir) { File.join(repo_root_dir, component_name) }
  let(:repo_tmp_dir) { File.join(repo_root_dir, "tmp") }
  let(:component_tmp_dir) { File.join(component_dir, "tmp") }
  let(:artifact_dir) { Toys::Release::ArtifactDir.new }
  let(:sample_release_version) { Gem::Version.new("0.99.99") }
  let(:performer_result) { Toys::Release::Performer::Result.new(component_name, sample_release_version) }
  let(:pipeline) do
    Toys::Release::Pipeline.new(repository: repository, component: component, version: sample_release_version,
                                performer_result: performer_result, artifact_dir: artifact_dir,
                                dry_run: true, git_remote: nil)
  end
  let(:orig_data_dir) { File.join(__dir__, ".data") }
  let(:temp_dir) { artifact_dir.temp("temp") }
  let(:step1_dir) { artifact_dir.output("step1") }
  let(:noop_output_dir) { artifact_dir.output("noop") }
  let(:noop_temp_dir) { artifact_dir.temp("noop") }
  let(:existing_content) { "# Existing file\n" }

  def make_step_settings(options = {})
    Toys::Release::StepSettings.new({"name" => "noop", "clean" => false}.merge(options), [])
  end

  def copy_data(dest_dir)
    FileUtils.mkdir_p(dest_dir)
    Dir.children(orig_data_dir).each do |child|
      src = File.join(orig_data_dir, child)
      dest = File.join(dest_dir, child == "tmp1" ? "tmp" : child)
      FileUtils.cp_r(src, dest)
    end
  end

  def disable_git_reset
    fake_tool_context.stub_exec(["git", "reset", "--hard"])
  end

  after do
    artifact_dir.cleanup
  end

  it "cleans a tree" do
    pipeline.add_step(make_step_settings({"clean" => true})).mark_will_run!
    allowed = [
      "changelog1.md",
      "version1.rb",
      "dir1/file1.md",
    ]
    fake_tool_context.stub_capture(["git", "ls-files"], output: allowed.join("\n"))
    fake_tool_context.stub_exec(["git", "reset", "--hard"]) do
      FileUtils.touch("version9.rb")
    end
    copy_data(temp_dir)
    Dir.chdir(temp_dir) do
      pipeline.run
      assert(File.exist?("changelog1.md"))
      refute(File.exist?("changelog2.md"))
      assert(File.exist?("dir1/file1.md"))
      refute(File.exist?("dir2/file2.md"))
      assert(File.exist?("version9.rb"))
    end
  end

  it "pulls specific input and output path to the component directory" do
    step_opts = {"inputs" => [{"name" => "step1", "source_path" => "dir1/subdir1", "dest_path" => "tmp"}]}
    pipeline.add_step(make_step_settings(step_opts)).mark_will_run!
    copy_data(step1_dir)
    FileUtils.rm_rf(component_tmp_dir)
    disable_git_reset
    pipeline.run
    assert(File.exist?(File.join(component_tmp_dir, "file11.md")))
  end

  it "pulls specific input to the repo root directory" do
    step_opts = {"inputs" => [{"name" => "step1", "source_path" => "tmp", "dest" => "repo_root"}]}
    pipeline.add_step(make_step_settings(step_opts)).mark_will_run!
    copy_data(step1_dir)
    FileUtils.rm_rf(repo_tmp_dir)
    disable_git_reset
    pipeline.run
    assert(File.exist?(File.join(repo_tmp_dir, "tmp.md")))
  end

  it "pulls entire input to the output directory" do
    step_opts = {"inputs" => [{"name" => "step1", "dest" => "output"}]}
    pipeline.add_step(make_step_settings(step_opts)).mark_will_run!
    copy_data(step1_dir)
    disable_git_reset
    pipeline.run
    assert(File.exist?(File.join(noop_output_dir, "dir1", "subdir1", "file11.md")))
    assert(File.exist?(File.join(noop_output_dir, "changelog1.md")))
  end

  it "pulls entire input to the temp directory" do
    step_opts = {"inputs" => [{"name" => "step1", "dest" => "temp"}]}
    pipeline.add_step(make_step_settings(step_opts)).mark_will_run!
    copy_data(step1_dir)
    disable_git_reset
    pipeline.run
    assert(File.exist?(File.join(noop_temp_dir, "dir1", "subdir1", "file11.md")))
    assert(File.exist?(File.join(noop_temp_dir, "changelog1.md")))
  end

  it "merges directories when pulling input" do
    step_opts = {"inputs" => [{"name" => "step1", "dest" => "temp"}]}
    pipeline.add_step(make_step_settings(step_opts)).mark_will_run!
    copy_data(step1_dir)
    FileUtils.mkdir_p(File.join(noop_temp_dir, "dir1"))
    File.write(File.join(noop_temp_dir, "dir1", "file1a.md"), existing_content)
    disable_git_reset
    pipeline.run
    assert_equal(File.read(File.join(orig_data_dir, "dir1", "file1.md")),
                 File.read(File.join(noop_temp_dir, "dir1", "file1.md")))
    assert_equal(existing_content, File.read(File.join(noop_temp_dir, "dir1", "file1a.md")))
    refute_includes(fake_tool_context.log_output, "Aborted pipeline:")
  end

  it "errors on file-on-file collision when pulling input" do
    step_opts = {"inputs" => [{"name" => "step1", "dest" => "temp"}]}
    pipeline.add_step(make_step_settings(step_opts)).mark_will_run!
    copy_data(step1_dir)
    FileUtils.mkdir_p(File.join(noop_temp_dir, "dir1"))
    File.write(File.join(noop_temp_dir, "dir1", "file1.md"), existing_content)
    disable_git_reset
    pipeline.run
    assert_includes(fake_tool_context.log_output, "Aborted pipeline: Unable to copy ./dir1/file1.md")
  end

  it "errors on directory-on-file collision when pulling input" do
    step_opts = {"inputs" => [{"name" => "step1", "dest" => "temp"}]}
    pipeline.add_step(make_step_settings(step_opts)).mark_will_run!
    copy_data(step1_dir)
    FileUtils.mkdir_p(File.join(noop_temp_dir, "dir1"))
    File.write(File.join(noop_temp_dir, "dir1", "subdir1"), existing_content)
    disable_git_reset
    pipeline.run
    assert_includes(fake_tool_context.log_output, "Aborted pipeline: Unable to copy ./dir1/subdir1")
  end

  it "errors on file-on-directory collision when pulling input" do
    step_opts = {"inputs" => [{"name" => "step1", "dest" => "temp"}]}
    pipeline.add_step(make_step_settings(step_opts)).mark_will_run!
    copy_data(step1_dir)
    FileUtils.mkdir_p(File.join(noop_temp_dir, "dir1", "file1.md"))
    File.write(File.join(noop_temp_dir, "dir1", "file1.md", "file1a.md"), existing_content)
    disable_git_reset
    pipeline.run
    assert_includes(fake_tool_context.log_output, "Aborted pipeline: Unable to copy ./dir1/file1.md")
  end

  it "replaces on file-on-file collision when pulling input" do
    step_opts = {"inputs" => [{"name" => "step1", "dest" => "temp", "collisions" => "replace"}]}
    pipeline.add_step(make_step_settings(step_opts)).mark_will_run!
    copy_data(step1_dir)
    FileUtils.mkdir_p(File.join(noop_temp_dir, "dir1"))
    File.write(File.join(noop_temp_dir, "dir1", "file1.md"), existing_content)
    disable_git_reset
    pipeline.run
    assert_equal(File.read(File.join(orig_data_dir, "dir1", "file1.md")),
                 File.read(File.join(noop_temp_dir, "dir1", "file1.md")))
    refute_includes(fake_tool_context.log_output, "Aborted pipeline:")
  end

  it "keeps on file-on-file collision when pulling input" do
    step_opts = {"inputs" => [{"name" => "step1", "dest" => "temp", "collisions" => "keep"}]}
    pipeline.add_step(make_step_settings(step_opts)).mark_will_run!
    copy_data(step1_dir)
    FileUtils.mkdir_p(File.join(noop_temp_dir, "dir1"))
    File.write(File.join(noop_temp_dir, "dir1", "file1.md"), existing_content)
    disable_git_reset
    pipeline.run
    assert_equal(existing_content, File.read(File.join(noop_temp_dir, "dir1", "file1.md")))
    refute_includes(fake_tool_context.log_output, "Aborted pipeline:")
  end

  it "pushes specific input and output path from the component directory" do
    step_opts = {"outputs" => [{"source_path" => "tmp/dir1/subdir1", "dest_path" => "dir1/subdir1"}]}
    pipeline.add_step(make_step_settings(step_opts)).mark_will_run!
    FileUtils.rm_rf(component_tmp_dir)
    copy_data(component_tmp_dir)
    disable_git_reset
    pipeline.run
    assert(File.exist?(File.join(noop_output_dir, "dir1", "subdir1", "file11.md")))
    refute(File.exist?(File.join(noop_output_dir, "changelog1.md")))
  end

  it "pushes specific input from the repo root directory" do
    step_opts = {"outputs" => [{"source" => "repo_root", "source_path" => "tmp/dir2"}]}
    pipeline.add_step(make_step_settings(step_opts)).mark_will_run!
    FileUtils.rm_rf(repo_tmp_dir)
    copy_data(repo_tmp_dir)
    disable_git_reset
    pipeline.run
    assert(File.exist?(File.join(noop_output_dir, "tmp", "dir2", "file2.md")))
    refute(File.exist?(File.join(noop_output_dir, "tmp", "dir1", "file1.md")))
  end

  it "pushes entire output from the temp directory" do
    step_opts = {"outputs" => [{"source" => "temp"}]}
    pipeline.add_step(make_step_settings(step_opts)).mark_will_run!
    copy_data(noop_temp_dir)
    disable_git_reset
    pipeline.run
    assert(File.exist?(File.join(noop_output_dir, "dir1", "subdir1", "file11.md")))
    assert(File.exist?(File.join(noop_output_dir, "changelog1.md")))
  end

  it "merges directories when pushing output" do
    step_opts = {"outputs" => [{"source" => "temp"}]}
    pipeline.add_step(make_step_settings(step_opts)).mark_will_run!
    copy_data(noop_temp_dir)
    FileUtils.mkdir_p(File.join(noop_output_dir, "dir1"))
    File.write(File.join(noop_output_dir, "dir1", "file1a.md"), existing_content)
    disable_git_reset
    pipeline.run
    assert_equal(File.read(File.join(noop_temp_dir, "dir1", "file1.md")),
                 File.read(File.join(noop_output_dir, "dir1", "file1.md")))
    assert_equal(existing_content, File.read(File.join(noop_output_dir, "dir1", "file1a.md")))
    refute_includes(fake_tool_context.log_output, "Aborted pipeline:")
  end

  it "errors on collision when pushing output" do
    step_opts = {"outputs" => [{"source" => "temp"}]}
    pipeline.add_step(make_step_settings(step_opts)).mark_will_run!
    copy_data(noop_temp_dir)
    FileUtils.mkdir_p(File.join(noop_output_dir, "dir1"))
    File.write(File.join(noop_output_dir, "dir1", "file1.md"), existing_content)
    disable_git_reset
    pipeline.run
    assert_includes(fake_tool_context.log_output, "Aborted pipeline: Unable to copy ./dir1/file1.md")
  end

  it "replaces on collision when pushing output" do
    step_opts = {"outputs" => [{"source" => "temp", "collisions" => "replace"}]}
    pipeline.add_step(make_step_settings(step_opts)).mark_will_run!
    copy_data(noop_temp_dir)
    FileUtils.mkdir_p(File.join(noop_output_dir, "dir1"))
    File.write(File.join(noop_output_dir, "dir1", "file1.md"), existing_content)
    disable_git_reset
    pipeline.run
    assert_equal(File.read(File.join(noop_temp_dir, "dir1", "file1.md")),
                 File.read(File.join(noop_output_dir, "dir1", "file1.md")))
    refute_includes(fake_tool_context.log_output, "Aborted pipeline:")
  end

  it "keeps on collision when pushing output" do
    step_opts = {"outputs" => [{"source" => "temp", "collisions" => "keep"}]}
    pipeline.add_step(make_step_settings(step_opts)).mark_will_run!
    copy_data(noop_temp_dir)
    FileUtils.mkdir_p(File.join(noop_output_dir, "dir1"))
    File.write(File.join(noop_output_dir, "dir1", "file1.md"), existing_content)
    disable_git_reset
    pipeline.run
    assert_equal(existing_content, File.read(File.join(noop_output_dir, "dir1", "file1.md")))
    refute_includes(fake_tool_context.log_output, "Aborted pipeline:")
  end

  it "defaults steps not to run" do
    step1 = pipeline.add_step(make_step_settings)
    step2 = pipeline.add_step(make_step_settings({"name" => "step2", "type" => "noop"}))
    pipeline.resolve_run
    refute(step1.will_run?)
    refute(step2.will_run?)
  end

  it "marks a step as runnable when explicitly requested" do
    step1 = pipeline.add_step(make_step_settings)
    step2 = pipeline.add_step(make_step_settings({"name" => "step2", "type" => "noop", "run" => true}))
    pipeline.resolve_run
    refute(step1.will_run?)
    assert(step2.will_run?)
  end

  it "marks a step as runnable when declared as an input" do
    step1 = pipeline.add_step(make_step_settings)
    step2 = pipeline.add_step(
      make_step_settings({"name" => "step2", "type" => "noop", "run" => true, "inputs" => [{"name" => "noop"}]})
    )
    pipeline.resolve_run
    assert(step1.will_run?)
    assert(step2.will_run?)
  end

  it "defaults non-primary standard steps not to run" do
    step1 = pipeline.add_step(make_step_settings({"type" => "tool", "command" => ["do"]}))
    step2 = pipeline.add_step(make_step_settings({"type" => "command", "command" => ["true"]}))
    step3 = pipeline.add_step(make_step_settings({"type" => "bundle"}))
    step4 = pipeline.add_step(make_step_settings({"type" => "build_gem"}))
    step5 = pipeline.add_step(make_step_settings({"type" => "build_yard"}))
    pipeline.resolve_run
    refute(step1.will_run?)
    refute(step2.will_run?)
    refute(step3.will_run?)
    refute(step4.will_run?)
    refute(step5.will_run?)
  end

  it "marks primary standard steps and their dependencies as runnable" do
    step1 = pipeline.add_step(make_step_settings({"name" => "tool", "command" => ["do"]}))
    step2 = pipeline.add_step(make_step_settings({"name" => "command", "command" => ["true"]}))
    step3 = pipeline.add_step(make_step_settings({"name" => "bundle"}))
    step4 = pipeline.add_step(make_step_settings({"name" => "build_gem"}))
    step5 = pipeline.add_step(make_step_settings({"name" => "build_yard"}))
    step6 = pipeline.add_step(make_step_settings({"name" => "release_gem"}))
    step7 = pipeline.add_step(make_step_settings({"name" => "push_gh_pages"}))
    step8 = pipeline.add_step(make_step_settings({"name" => "release_github"}))
    Dir.chdir(component_dir) do
      pipeline.resolve_run
    end
    refute(step1.will_run?)
    refute(step2.will_run?)
    assert(step3.will_run?)
    assert(step4.will_run?)
    assert(step5.will_run?)
    assert(step6.will_run?)
    assert(step7.will_run?)
    assert(step8.will_run?)
  end

  describe "StepContext" do
    it "provides information for a default noop" do
      step = pipeline.add_step(make_step_settings)
      refute(step.requested?)
      assert_equal("noop", step.name)
      assert_equal([], step.input_settings)
      assert_equal([], step.output_settings)
      assert_equal(environment_utils, step.utils)
      assert_equal(repository, step.repository)
      assert_equal(component, step.component)
      assert_equal(sample_release_version, step.release_version)
      assert_equal("origin", step.git_remote)
      assert(step.dry_run?)
      assert_equal("toys-release 0.99.99", step.release_description)
      assert_equal("toys-release-0.99.99.gem", step.gem_package_name)
      assert_equal("toys-release/v0.99.99", step.tag_name)
    end

    it "provides information for a customized step" do
      pipeline = Toys::Release::Pipeline.new(
        repository: repository, component: component, version: sample_release_version,
        performer_result: performer_result, artifact_dir: artifact_dir,
        dry_run: false, git_remote: "upstream"
      )
      settings_info = {
        "name" => "my_build",
        "inputs" => "step1",
        "outputs" => "a.out",
        "run" => true,
      }
      step = pipeline.add_step(make_step_settings(settings_info))
      assert(step.requested?)
      assert_equal("my_build", step.name)
      assert_equal(1, step.input_settings.size)
      assert_equal("step1", step.input_settings.first.step_name)
      assert_equal(1, step.output_settings.size)
      assert_equal("a.out", step.output_settings.first.source_path)
      assert_equal(environment_utils, step.utils)
      assert_equal(repository, step.repository)
      assert_equal(component, step.component)
      assert_equal(sample_release_version, step.release_version)
      assert_equal("upstream", step.git_remote)
      refute(step.dry_run?)
      assert_equal("toys-release 0.99.99", step.release_description)
      assert_equal("toys-release-0.99.99.gem", step.gem_package_name)
      assert_equal("toys-release/v0.99.99", step.tag_name)
    end

    it "exits a step" do
      step = pipeline.add_step(make_step_settings)
      ex = assert_raises(Toys::Release::Pipeline::StepExit) do
        step.exit_step
      end
      assert_equal(ex.class.name, ex.message)
    end

    it "exits a step with a message" do
      step = pipeline.add_step(make_step_settings)
      ex = assert_raises(Toys::Release::Pipeline::StepExit) do
        step.exit_step("Stopped early")
      end
      assert_equal("Stopped early", ex.message)
    end

    it "aborts the pipeline" do
      step = pipeline.add_step(make_step_settings)
      ex = assert_raises(Toys::Release::Pipeline::PipelineExit) do
        step.abort_pipeline("Aborted pipeline 2")
      end
      assert_equal("Aborted pipeline 2", ex.message)
    end

    it "gets option values" do
      step = pipeline.add_step(make_step_settings({"opt1" => "val1", "opt2" => "val2"}))
      assert_equal("val1", step.option("opt1"))
      assert_nil(step.option("opt3"))
      assert_equal("val3", step.option("opt3", default: "val3"))
      assert_raises(Toys::Release::Pipeline::PipelineExit) do
        step.option("opt3", required: true)
      end
    end

    it "copies specific input and output path to the component directory" do
      step = pipeline.add_step(make_step_settings)
      copy_data(step1_dir)
      FileUtils.rm_rf(component_tmp_dir)
      step.copy_from_input("step1", source_path: "dir1/subdir1", dest_path: "tmp")
      assert(File.exist?(File.join(component_tmp_dir, "file11.md")))
    end

    it "copies specific input to the repo root directory" do
      step = pipeline.add_step(make_step_settings)
      copy_data(step1_dir)
      FileUtils.rm_rf(repo_tmp_dir)
      step.copy_from_input("step1", source_path: "tmp", dest: :repo_root)
      assert(File.exist?(File.join(repo_tmp_dir, "tmp.md")))
    end

    it "copies entire input to the output directory" do
      step = pipeline.add_step(make_step_settings)
      copy_data(step1_dir)
      step.copy_from_input("step1", dest: :output)
      assert(File.exist?(File.join(noop_output_dir, "dir1", "subdir1", "file11.md")))
      assert(File.exist?(File.join(noop_output_dir, "changelog1.md")))
    end

    it "copies entire input to the temp directory" do
      step = pipeline.add_step(make_step_settings)
      copy_data(step1_dir)
      step.copy_from_input("step1", dest: :temp)
      assert(File.exist?(File.join(noop_temp_dir, "dir1", "subdir1", "file11.md")))
      assert(File.exist?(File.join(noop_temp_dir, "changelog1.md")))
    end

    it "merges directories when copying input" do
      step = pipeline.add_step(make_step_settings)
      copy_data(step1_dir)
      FileUtils.mkdir_p(File.join(noop_temp_dir, "dir1"))
      File.write(File.join(noop_temp_dir, "dir1", "file1a.md"), existing_content)
      step.copy_from_input("step1", dest: :temp)
      assert_equal(File.read(File.join(orig_data_dir, "dir1", "file1.md")),
                   File.read(File.join(noop_temp_dir, "dir1", "file1.md")))
      assert_equal(existing_content, File.read(File.join(noop_temp_dir, "dir1", "file1a.md")))
    end

    it "errors on collision when copying input" do
      step = pipeline.add_step(make_step_settings)
      copy_data(step1_dir)
      FileUtils.mkdir_p(File.join(noop_temp_dir, "dir1"))
      File.write(File.join(noop_temp_dir, "dir1", "file1.md"), existing_content)
      ex = assert_raises(Toys::Release::Pipeline::PipelineExit) do
        step.copy_from_input("step1", dest: :temp)
      end
      assert_includes(ex.message, "Unable to copy ./dir1/file1.md")
    end

    it "replaces on collision when copying input" do
      step = pipeline.add_step(make_step_settings)
      copy_data(step1_dir)
      FileUtils.mkdir_p(File.join(noop_temp_dir, "dir1"))
      File.write(File.join(noop_temp_dir, "dir1", "file1.md"), existing_content)
      step.copy_from_input("step1", dest: :temp, collisions: :replace)
      assert_equal(File.read(File.join(orig_data_dir, "dir1", "file1.md")),
                   File.read(File.join(noop_temp_dir, "dir1", "file1.md")))
    end

    it "keeps on collision when copying input" do
      step = pipeline.add_step(make_step_settings)
      copy_data(step1_dir)
      FileUtils.mkdir_p(File.join(noop_temp_dir, "dir1"))
      File.write(File.join(noop_temp_dir, "dir1", "file1.md"), existing_content)
      step.copy_from_input("step1", dest: :temp, collisions: :keep)
      assert_equal(existing_content, File.read(File.join(noop_temp_dir, "dir1", "file1.md")))
    end

    it "copies specific input and output path from the component directory" do
      step = pipeline.add_step(make_step_settings)
      FileUtils.rm_rf(component_tmp_dir)
      copy_data(component_tmp_dir)
      step.copy_to_output(source_path: "tmp/dir1/subdir1", dest_path: "dir1/subdir1")
      assert(File.exist?(File.join(noop_output_dir, "dir1", "subdir1", "file11.md")))
      refute(File.exist?(File.join(noop_output_dir, "changelog1.md")))
    end

    it "copies specific input from the repo root directory" do
      step = pipeline.add_step(make_step_settings)
      FileUtils.rm_rf(repo_tmp_dir)
      copy_data(repo_tmp_dir)
      step.copy_to_output(source: :repo_root, source_path: "tmp/dir2")
      assert(File.exist?(File.join(noop_output_dir, "tmp", "dir2", "file2.md")))
      refute(File.exist?(File.join(noop_output_dir, "tmp", "dir1", "file1.md")))
    end

    it "copies entire output from the temp directory" do
      step = pipeline.add_step(make_step_settings)
      copy_data(noop_temp_dir)
      step.copy_to_output(source: :temp)
      assert(File.exist?(File.join(noop_output_dir, "dir1", "subdir1", "file11.md")))
      assert(File.exist?(File.join(noop_output_dir, "changelog1.md")))
    end

    it "merges directories when copying output" do
      step = pipeline.add_step(make_step_settings)
      copy_data(noop_temp_dir)
      FileUtils.mkdir_p(File.join(noop_output_dir, "dir1"))
      File.write(File.join(noop_output_dir, "dir1", "file1a.md"), existing_content)
      step.copy_to_output(source: :temp)
      assert_equal(File.read(File.join(orig_data_dir, "dir1", "file1.md")),
                   File.read(File.join(noop_output_dir, "dir1", "file1.md")))
      assert_equal(existing_content, File.read(File.join(noop_output_dir, "dir1", "file1a.md")))
    end

    it "errors on collision when copying output" do
      step = pipeline.add_step(make_step_settings)
      copy_data(noop_temp_dir)
      FileUtils.mkdir_p(File.join(noop_output_dir, "dir1"))
      File.write(File.join(noop_output_dir, "dir1", "file1.md"), existing_content)
      ex = assert_raises(Toys::Release::Pipeline::PipelineExit) do
        step.copy_to_output(source: :temp)
      end
      assert_includes(ex.message, "Unable to copy ./dir1/file1.md")
    end

    it "replaces on collision when copying output" do
      step = pipeline.add_step(make_step_settings)
      copy_data(noop_temp_dir)
      FileUtils.mkdir_p(File.join(noop_output_dir, "dir1"))
      File.write(File.join(noop_output_dir, "dir1", "file1.md"), existing_content)
      step.copy_to_output(source: :temp, collisions: :replace)
      assert_equal(File.read(File.join(orig_data_dir, "dir1", "file1.md")),
                   File.read(File.join(noop_output_dir, "dir1", "file1.md")))
    end

    it "keeps on collision when copying output" do
      step = pipeline.add_step(make_step_settings)
      copy_data(noop_temp_dir)
      FileUtils.mkdir_p(File.join(noop_output_dir, "dir1"))
      File.write(File.join(noop_output_dir, "dir1", "file1.md"), existing_content)
      step.copy_to_output(source: :temp, collisions: :keep)
      assert_equal(existing_content, File.read(File.join(noop_output_dir, "dir1", "file1.md")))
    end
  end
end
