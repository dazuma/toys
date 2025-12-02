# frozen_string_literal: true

require_relative "helper"

describe "toys release gen-config" do
  include Toys::Testing

  describe "internal methods" do
    let(:repo_root) { ::File.dirname(::File.dirname(::File.dirname(__dir__))) }

    it "determines the github repo of this repo" do
      toys_load_tool(["gen-config"]) do |tool|
        out, _err = capture_subprocess_io do
          tool.interpret_github_repo
        end
        assert_includes(out, "GitHub repository inferred to be dazuma/toys")
        assert_equal("dazuma/toys", tool.repo)
      end
    end

    it "checks the file path in this repo" do
      toys_load_tool(["gen-config"]) do |tool|
        Dir.chdir(repo_root) do
          out, _err = capture_subprocess_io do
            result = catch(:result) do
              tool.check_file_path
              nil
            end
            assert_equal(1, result)
          end
          assert_includes(out, "Cannot overwrite existing file: .toys/.data/releases.yml")
        end
      end
    end

    it "finds gems in this repo" do
      toys_load_tool(["gen-config"]) do |tool|
        Dir.chdir(repo_root) do
          out, _err = capture_subprocess_io do
            found = tool.find_gems
            assert_equal(3, found.size)
            found.sort_by!(&:first)
            assert_equal([["toys", "toys"], ["toys-core", "toys-core"], ["toys-release", "toys-release"]], found)
          end
          assert_includes(out, "Found toys/toys.gemspec in the repo.")
          assert_includes(out, "Found toys-core/toys-core.gemspec in the repo.")
          assert_includes(out, "Found toys-release/toys-release.gemspec in the repo.")
        end
      end
    end

    it "writes custom settings with sorted gems" do
      toys_load_tool(["gen-config", "--repo=hello/world"]) do |tool|
        io = StringIO.new
        tool.write_settings(io, [["foo", "foo1"], ["bar", "bar2"]])
        expected_yaml = {
          "repo" => "hello/world",
          "gems" => [
            {
              "name" => "bar",
              "directory" => "bar2",
            },
            {
              "name" => "foo",
              "directory" => "foo1",
            },
          ],
        }
        assert_equal(expected_yaml, ::YAML.safe_load(io.string))
      end
    end
  end

  describe "tool" do
    let(:temp_dir) { ::Dir.mktmpdir }

    after do
      ::FileUtils.remove_entry(temp_dir)
    end

    it "creates a file for this repo" do
      file_path = ::File.join(temp_dir, "releases.yml")
      out, _err = capture_subprocess_io do
        code = toys_run_tool(["gen-config", "-o", file_path, "-y"])
        assert_equal(0, code)
      end
      expected_yaml = {
        "repo" => "dazuma/toys",
        "gems" => [
          {
            "name" => "toys",
            "directory" => "toys",
          },
          {
            "name" => "toys-core",
            "directory" => "toys-core",
          },
          {
            "name" => "toys-release",
            "directory" => "toys-release",
          },
        ],
      }
      assert_equal(expected_yaml, ::YAML.load_file(file_path))
      assert_includes(out, "Wrote initial config file to #{file_path}")
    end
  end
end
