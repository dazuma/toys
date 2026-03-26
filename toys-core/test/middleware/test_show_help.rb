# frozen_string_literal: true

require "helper"
require "stringio"
require "toys/standard_middleware/show_help"

describe Toys::StandardMiddleware::ShowHelp do
  let(:logger) {
    Logger.new(StringIO.new).tap do |lgr|
      lgr.level = Logger::WARN
    end
  }
  let(:executable_name) { "toys" }
  let(:string_io) { ::StringIO.new }
  def make_cli(**opts)
    middleware = [[Toys::StandardMiddleware::ShowHelp, opts.merge(stream: string_io)]]
    Toys::CLI.new(executable_name: executable_name, logger: logger, middleware_stack: middleware)
  end

  it "causes a tool to respond to help flags" do
    cli = make_cli(help_flags: true)
    cli.add_config_block do
      tool "foo" do
        # Empty tool
      end
    end
    cli.run("foo", "--help")
    assert_match(/SYNOPSIS.*toys foo/m, string_io.string)
  end

  it "causes a tool to respond to usage flags" do
    cli = make_cli(usage_flags: true)
    cli.add_config_block do
      tool "foo" do
        # Empty tool
      end
    end
    cli.run("foo", "--usage")
    assert_match(/Usage:\s+toys foo/, string_io.string)
  end

  it "causes a tool to respond to list flags" do
    cli = make_cli(list_flags: true)
    cli.add_config_block do
      tool "foo" do
        # Empty tool
      end
    end
    cli.run("--tools")
    assert_match(/List of tools:/, string_io.string)
  end

  it "implements fallback execution" do
    cli = make_cli(fallback_execution: true)
    cli.add_config_block do
      tool "foo" do
        # Empty tool
      end
    end
    cli.run("foo")
    assert_match(/SYNOPSIS.*toys foo/m, string_io.string)
  end

  it "supports root args" do
    cli = make_cli(help_flags: true, allow_root_args: true)
    cli.add_config_block do
      tool "foo" do
        tool "bar" do
          # Empty tool
        end
      end
    end
    cli.run("--help", "foo", "bar")
    assert_match(/SYNOPSIS.*toys foo bar/m, string_io.string)
  end

  it "supports search flag" do
    cli = make_cli(fallback_execution: true, search_flags: true)
    cli.add_config_block do
      tool "foo" do
        desc "beyond all recognition"
        def run; end
      end
      tool "bar" do
        desc "was met"
        def run; end
      end
    end
    cli.run("--search", "bar")
    refute_match(/foo/, string_io.string)
    assert_match(/bar - was met/, string_io.string)
  end

  it "reports bad search syntax" do
    cli = make_cli(fallback_execution: true, search_flags: true)
    cli.add_config_block do
      tool "foo" do
        desc "beyond all recognition"
        def run; end
      end
      tool "bar" do
        desc "was met"
        def run; end
      end
    end
    result = cli.run("--search", "bar[")
    assert_match(/Unable to generate help: Bad search regex/, string_io.string)
    assert_equal(1, result)
  end

  it "does not show hidden tools by default" do
    cli = make_cli(fallback_execution: true, show_all_subtools_flags: true)
    cli.add_config_block do
      tool "_bar" do
        desc "was met"
        def run; end
      end
    end
    cli.run
    refute_match(/bar - was met/, string_io.string)
  end

  it "Shows hidden tools when requested" do
    cli = make_cli(fallback_execution: true, show_all_subtools_flags: true)
    cli.add_config_block do
      tool "_bar" do
        desc "was met"
        def run; end
      end
    end
    cli.run("--all")
    assert_match(/_bar - was met/, string_io.string)
  end

  it "does not recurse by default" do
    cli = make_cli(fallback_execution: true)
    cli.add_config_block do
      tool "foo" do
        desc "beyond all recognition"
        tool "bar" do
          desc "was met"
          def run; end
        end
      end
    end
    cli.run
    refute_match(/bar - was met/, string_io.string)
  end

  it "supports default recursive listing" do
    cli = make_cli(fallback_execution: true, default_recursive: true)
    cli.add_config_block do
      tool "foo" do
        desc "beyond all recognition"
        tool "bar" do
          desc "was met"
          def run; end
        end
      end
    end
    cli.run
    assert_match(/bar - was met/, string_io.string)
  end

  it "supports set-recursive flag" do
    cli = make_cli(fallback_execution: true, recursive_flags: true)
    cli.add_config_block do
      tool "foo" do
        desc "beyond all recognition"
        tool "bar" do
          desc "was met"
          def run; end
        end
      end
    end
    cli.run("--recursive")
    assert_match(/bar - was met/, string_io.string)
  end

  it "supports clear-recursive flag" do
    cli = make_cli(fallback_execution: true, default_recursive: true, recursive_flags: true)
    cli.add_config_block do
      tool "foo" do
        desc "beyond all recognition"
        tool "bar" do
          desc "was met"
          def run; end
        end
      end
    end
    cli.run("--no-recursive")
    refute_match(/bar - was met/, string_io.string)
  end

  describe "proc-valued flag specs" do
    it "uses default help flags when the proc returns true" do
      cli = make_cli(help_flags: proc { |_tool| true })
      cli.add_config_block do
        tool "foo" do
          # Empty tool
        end
      end
      cli.run("foo", "--help")
      assert_match(/SYNOPSIS.*toys foo/m, string_io.string)
    end

    it "uses custom help flags when the proc returns an array" do
      cli = make_cli(help_flags: proc { |_tool| ["-H", "--info"] })
      cli.add_config_block do
        tool "foo" do
          # Empty tool
        end
      end
      cli.run("foo", "-H")
      assert_match(/SYNOPSIS.*toys foo/m, string_io.string)
    end

    it "passes the tool to the proc so flags can be applied conditionally" do
      cli = make_cli(
        help_flags: proc { |tool| tool.full_name == ["foo"] },
        fallback_execution: true
      )
      cli.add_config_block do
        tool "foo" do
          # Empty non-runnable tool
        end
        tool "bar" do
          # Empty non-runnable tool
        end
      end
      cli.run("foo", "--help")
      assert_match(/SYNOPSIS.*toys foo/m, string_io.string)
      string_io.truncate(0)
      string_io.rewind
      cli.run("bar")
      assert_match(/SYNOPSIS.*toys bar/m, string_io.string)
      refute_includes(string_io.string, "--help")
    end
  end

  describe "report_usage_error" do
    let(:cli) {
      make_cli(help_flags: true, allow_root_args: true)
    }

    before do
      cli.add_config_block do
        tool "foo" do
          desc "the foo tool"
          tool "bar" do
            desc "the bar tool"
          end
        end
      end
    end

    it "shows an error and exits 1 when the root arg tool is not found" do
      exit_code = cli.run("--help", "nonexistent")
      assert_equal(1, exit_code)
      assert_match(/Tool not found: "nonexistent"/, string_io.string)
      assert_match(/Usage:/, string_io.string)
    end

    it "shows the parent tool usage when a subtool of a root arg is not found" do
      exit_code = cli.run("--help", "foo", "nonexistent")
      assert_equal(1, exit_code)
      assert_match(/Tool not found: "foo nonexistent"/, string_io.string)
      assert_match(/toys foo/, string_io.string)
    end
  end

  describe "when a runnable tool has subtools" do
    let(:cli) {
      make_cli(
        help_flags: true, usage_flags: true, list_flags: true,
        search_flags: true, recursive_flags: true, show_all_subtools_flags: true
      )
    }

    it "omits subtool filter flags" do
      cli.add_config_block do
        tool "foo" do
          desc "beyond all recognition"
          def run; end
          tool "bar" do
            desc "was met"
            def run; end
          end
        end
      end
      cli.run("foo", "--help")
      output = string_io.string
      assert_includes(output, "--help")
      assert_includes(output, "--tools")
      assert_includes(output, "--usage")
      refute_includes(output, "--all")
      refute_includes(output, "--[no-]recursive")
      refute_includes(output, "--search")
    end

    it "still supports usage" do
      cli.add_config_block do
        tool "foo" do
          desc "beyond all recognition"
          def run; end
          tool "bar" do
            desc "was met"
            def run; end
          end
        end
      end
      cli.run("foo", "--usage")
      assert_match(/Usage:\s+toys foo TOOL/, string_io.string)
    end

    it "still supports list tools" do
      cli.add_config_block do
        tool "foo" do
          desc "beyond all recognition"
          def run; end
          tool "bar" do
            desc "was met"
            def run; end
          end
        end
      end
      cli.run("foo", "--tools")
      assert_includes(string_io.string, "List of tools under foo:")
    end

    it "allows the tool to override usage flag" do
      cli.add_config_block do
        tool "foo" do
          desc "beyond all recognition"
          flag :usage
          def run
            puts "NORMAL RUN #{usage}"
          end
          tool "bar" do
            desc "was met"
            def run; end
          end
        end
      end
      out, _err = capture_subprocess_io do
        cli.run("foo", "--usage")
      end
      assert_includes(out, "NORMAL RUN true")
      assert_empty(string_io.string)
    end

    it "allows the tool to override list tools flag" do
      cli.add_config_block do
        tool "foo" do
          desc "beyond all recognition"
          flag :tools
          def run
            puts "NORMAL RUN #{tools}"
          end
          tool "bar" do
            desc "was met"
            def run; end
          end
        end
      end
      out, _err = capture_subprocess_io do
        cli.run("foo", "--tools")
      end
      assert_includes(out, "NORMAL RUN true")
      assert_empty(string_io.string)
    end
  end
end
