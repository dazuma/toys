# frozen_string_literal: true

require_relative "helper"

describe "toys release gen-workflows" do
  include Toys::Testing

  root_dir = ::File.dirname(::File.dirname(::File.dirname(__dir__)))
  toys_custom_paths(::File.join(root_dir, ".toys"))

  let(:temp_dir) { ::Dir.mktmpdir }
  let(:workflows_dir) { ::File.join(root_dir, ".github", "workflows") }

  after do
    ::FileUtils.remove_entry(temp_dir)
  end

  it "creates workflow files" do
    capture_subprocess_io do
      code = toys_run_tool(["release", "gen-workflows", "-o", temp_dir, "-y"])
      assert_equal(0, code)
    end
    files = [
      "release-hook-on-closed.yml",
      "release-hook-on-push.yml",
      "release-perform.yml",
      "release-request.yml",
      "release-retry.yml",
    ]
    files.each do |file|
      generated = ::File.read(::File.join(temp_dir, file))
      expected = ::File.read(::File.join(workflows_dir, file))
      assert_equal(expected, generated)
    end
  end
end
