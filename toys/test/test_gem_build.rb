# frozen_string_literal: true

require "helper"
require "toys/utils/exec"

describe "gem_build template" do
  let(:template_lookup) { Toys::ModuleLookup.new.add_path("toys/templates") }
  let(:toys_dir) { File.dirname(__dir__) }

  describe "unit functionality" do
    let(:template_class) { template_lookup.lookup(:gem_build) }
    let(:template) { template_class.new }

    it "handles the name field" do
      assert_equal("build", template.name)
      template.name = "hi"
      assert_equal("hi", template.name)
      template.name = nil
      assert_equal("build", template.name)
    end

    it "handles the gem_name field" do
      assert_equal("toys", template.gem_name)
      template.gem_name = "toys-core"
      assert_equal("toys-core", template.gem_name)
      template.gem_name = nil
      assert_equal("toys", template.gem_name)
    end

    it "handles the gem_name field with a context dir" do
      assert_equal("toys", template.gem_name(toys_dir))
      template.gem_name = "toys-core"
      assert_equal("toys-core", template.gem_name(toys_dir))
      template.gem_name = nil
      assert_equal("toys", template.gem_name(toys_dir))
    end

    it "handles the output field" do
      assert_nil(template.output)
      template.output = "/path/to/somewhere"
      assert_equal("/path/to/somewhere", template.output)
      template.output = nil
      assert_nil(template.output)
    end

    it "handles the output_flags field" do
      assert_equal([], template.output_flags)
      template.output_flags = "--out"
      assert_equal(["--out"], template.output_flags)
      template.output_flags = ["--out", "-o"]
      assert_equal(["--out", "-o"], template.output_flags)
      template.output_flags = true
      assert_equal(["-o", "--output"], template.output_flags)
      template.output_flags = nil
      assert_equal([], template.output_flags)
    end

    it "handles the push_tag field" do
      assert_equal(false, template.push_tag)
      template.push_tag = "upstream"
      assert_equal("upstream", template.push_tag)
      template.push_tag = true
      assert_equal("origin", template.push_tag)
      template.push_tag = false
      assert_equal(false, template.push_tag)
    end

    it "handles the task_names field" do
      assert_equal("Build", template.task_names)
      template.install_gem = true
      assert_equal("Install", template.task_names)
      template.push_gem = true
      assert_equal("Install and Release", template.task_names)
      template.install_gem = false
      assert_equal("Release", template.task_names)
      template.push_gem = false
      assert_equal("Build", template.task_names)
    end

    it "handles the context_directory field" do
      assert_nil(template.context_directory)
      template.context_directory = "/path/to/somewhere"
      assert_equal("/path/to/somewhere", template.context_directory)
      template.context_directory = nil
      assert_nil(template.context_directory)
    end

    it "honors constructor args" do
      template = template_class.new name: "hi",
                                    gem_name: "toys",
                                    output: "/path/to/output",
                                    output_flags: "--out",
                                    push_tag: true,
                                    install_gem: true,
                                    push_gem: true,
                                    context_directory: "/path/to/context"
      assert_equal("hi", template.name)
      assert_equal("toys", template.gem_name)
      assert_equal("/path/to/output", template.output)
      assert_equal(["--out"], template.output_flags)
      assert_equal("origin", template.push_tag)
      assert_equal("Install and Release", template.task_names)
      assert_equal("/path/to/context", template.context_directory)
    end
  end

  describe "integration functionality" do
    let(:cli) { Toys::CLI.new(middleware_stack: [], template_lookup: template_lookup) }
    let(:loader) { cli.loader }

    it "builds toys into tmp directory" do
      loader.add_block do
        expand :gem_build, output: "tmp/toys.gem"
      end
      Dir.chdir(toys_dir) do
        FileUtils.rm_rf("tmp")
        FileUtils.mkdir_p("tmp")
        out, _err = capture_subprocess_io do
          assert_equal(0, cli.run("build"))
        end
        assert_match(/Successfully built RubyGem/, out)
        assert(File.file?("tmp/toys.gem"))
        FileUtils.rm_rf("tmp")
      end
    end

    it "supports default output flags" do
      loader.add_block do
        expand :gem_build, output_flags: true
      end
      Dir.chdir(toys_dir) do
        FileUtils.rm_rf("tmp")
        FileUtils.mkdir_p("tmp")
        out, _err = capture_subprocess_io do
          assert_equal(0, cli.run("build", "-o", "tmp/toys.gem"))
        end
        assert_match(/Successfully built RubyGem/, out)
        assert(File.file?("tmp/toys.gem"))
        FileUtils.rm_rf("tmp")
      end
    end

    it "supports custom output flags" do
      loader.add_block do
        expand :gem_build, output_flags: ["--outfile"]
      end
      Dir.chdir(toys_dir) do
        FileUtils.rm_rf("tmp")
        FileUtils.mkdir_p("tmp")
        out, _err = capture_subprocess_io do
          assert_equal(0, cli.run("build", "--outfile", "tmp/toys.gem"))
        end
        assert_match(/Successfully built RubyGem/, out)
        assert(File.file?("tmp/toys.gem"))
        FileUtils.rm_rf("tmp")
      end
    end

    it "honors context_directory argument" do
      dir = toys_dir
      loader.add_block do
        expand :gem_build, output: "tmp/toys.gem", context_directory: dir
      end
      Dir.chdir(toys_dir) do
        FileUtils.rm_rf("tmp")
        FileUtils.mkdir_p("tmp")
        out, _err = capture_subprocess_io do
          Dir.chdir("tmp") do
            assert_equal(0, cli.run("build"))
          end
        end
        assert_match(/Successfully built RubyGem/, out)
        assert(File.file?("tmp/toys.gem"))
        FileUtils.rm_rf("tmp")
      end
    end
  end
end
