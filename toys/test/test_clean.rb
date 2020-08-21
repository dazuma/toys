# frozen_string_literal: true

require "helper"

describe "clean template" do
  let(:template_lookup) { Toys::ModuleLookup.new.add_path("toys/templates") }

  describe "unit functionality" do
    let(:template) { template_lookup.lookup(:clean).new }

    it "handles the name field" do
      assert_equal("clean", template.name)
      template.name = "hi"
      assert_equal("hi", template.name)
      template.name = nil
      assert_equal("clean", template.name)
    end

    it "handles the paths field" do
      assert_equal([], template.paths)
      template.paths = "/path/to/somewhere"
      assert_equal(["/path/to/somewhere"], template.paths)
      template.paths = nil
      assert_equal([], template.paths)
    end
  end

  describe "integration functionality" do
    let(:cli) { Toys::CLI.new(middleware_stack: [], template_lookup: template_lookup) }
    let(:loader) { cli.loader }
    let(:workspace_dir) { File.join(__dir__, "clean-workspace") }

    def clean_workspace
      Dir.foreach(workspace_dir) do |child|
        unless [".", "..", ".gitkeep"].include?(child)
          FileUtils.rm_rf(File.join(workspace_dir, child))
        end
      end
    end

    before { clean_workspace }
    after { clean_workspace }

    it "cleans a pattern" do
      dir = workspace_dir
      FileUtils.touch(File.join(dir, "foo.txt"))
      FileUtils.touch(File.join(dir, "bar.yml"))
      loader.add_block do
        set_context_directory dir
        expand :clean, paths: "*.txt"
      end
      out, _err = capture_subprocess_io do
        assert_equal(0, cli.run("clean"))
      end
      assert_equal("Cleaned: foo.txt\n", out)
      assert(File.exist?(File.join(dir, "bar.yml")))
      refute(File.exist?(File.join(dir, "foo.txt")))
    end

    it "cleans gitignore" do
      dir = workspace_dir
      FileUtils.touch(File.join(dir, "foo.txt"))
      FileUtils.touch(File.join(dir, "Gemfile.lock"))
      FileUtils.mkdir(File.join(dir, "tmp"))
      FileUtils.touch(File.join(dir, "tmp", "bar.txt"))
      FileUtils.mkdir(File.join(dir, "hello"))
      FileUtils.touch(File.join(dir, "hello", "baz.txt"))
      FileUtils.touch(File.join(dir, "hello", "Gemfile.lock"))
      loader.add_block do
        set_context_directory dir
        expand :clean, paths: :gitignore
      end
      out, _err = capture_subprocess_io do
        assert_equal(0, cli.run("clean"))
      end
      assert_equal("Cleaned: ./Gemfile.lock\nCleaned: ./tmp\nCleaned: ./hello/Gemfile.lock\n", out)
      assert(File.exist?(File.join(dir, "foo.txt")))
      assert(File.exist?(File.join(dir, "hello", "baz.txt")))
      refute(File.exist?(File.join(dir, "Gemfile.lock")))
      refute(File.exist?(File.join(dir, "tmp")))
      refute(File.exist?(File.join(dir, "hello", "Gemfile.lock")))
    end
  end
end
