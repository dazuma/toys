# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is the **toys** gem — the main CLI executable built on the toys-core framework. It provides the `toys` binary, the `StandardCLI` configuration, built-in tools, standard templates, and a test harness for tool authors. It depends on `toys-core` at the same version.

## Development Commands

From within the `toys` directory, use `toys` to run CI/test tasks specific to this gem. For example:

```bash
toys ci --only --current  # Run all CI tasks for this gem
toys test                 # Run just the library tests for this gem, omitting integration tests
toys test --integration   # Run just the library tests for this gem, including integration tests
toys test-builtins        # Run just tests of built-in tools in this gem
toys rubocop              # Run just RuboCop for this gem
```

To run individual test files directly, pass them as positional command line arguments. This must be run from within the `toys` gem directory, and will not work from the repository root.

```bash
toys test test/test_minitest.rb test/test_rspec.rb   # Run only the library tests in the given files
toys test-builtins builtins/.test/test_general.rb   # Run only the built-in tool tests in the given file
```

## Source Structure

### Entry Point

- **`bin/toys`** - The executable. Sets `TOYS_BIN_PATH` and `TOYS_LIB_PATH` env vars, then creates and runs a `StandardCLI`.
- **`lib/toys/version.rb`** - `Toys::VERSION` constant (must match toys-core's `Toys::Core::VERSION`).

### StandardCLI (`lib/toys/standard_cli.rb`)

Subclass of `Toys::CLI` that configures everything for the `toys` executable:

- File conventions: `.toys.rb` (config file and index file), `.toys/` (config dir), `.data/` (data dir), `.lib/` (lib dir), `.preload.rb` / `.preload/` (preloaded code)
- Tool name delimiters: spaces, colons, and periods (e.g. `toys system:version`)
- Default middleware stack: `set_default_descriptions`, `show_help`, `show_root_version`, `handle_usage_errors`, `add_verbosity_flags`
- Tool search path: walks up from the current directory, then global paths (`$HOME`, `/etc`, or `TOYS_PATH` env var)
- Loads built-in tools from `builtins/`
- Registers standard templates via `ModuleLookup` from `toys/templates`

### Testing Harness (`lib/toys/testing.rb`)

`Toys::Testing` module for tool authors to test their tools with Minitest:

- **`toys_run_tool(cmd)`** - Runs a tool in-process, returns exit code
- **`toys_load_tool(cmd) { |ctx| ... }`** - Loads a tool and yields the execution context for unit-testing individual methods
- **`toys_exec_tool(cmd)`** - Runs a tool in a forked subprocess, returns an `Exec::Result` with captured output
- **`toys_custom_paths(paths)`** - Class method to set tool search paths for tests
- Shares a single CLI/Loader per `describe` block for efficiency

### Built-in Tools (`builtins/`)

- **`do.rb`** - The `do` command for chaining multiple tool invocations (e.g. `toys do test , rubocop`)
- **`system/`** - System namespace:
  - `bash-completion.rb` - Shell completion setup/removal
  - `git-cache.rb` - Git cache management
  - `test.rb` - Built-in test runner
  - `tools.rb` - Tool introspection
  - `update.rb` - Self-update
  - `.test/` - Tests for builtins (run via `test-builtins` command)

### Templates (`lib/toys/templates/`)

Reusable tool generators invoked via `expand :template_name` in `.toys.rb` files:

- **`:clean`** - File cleanup tasks
- **`:minitest`** - Minitest test runner
- **`:rubocop`** - RuboCop linter
- **`:yardoc`** - YARD documentation generator
- **`:rdoc`** - RDoc documentation generator
- **`:gem_build`** - Gem build/release/install
- **`:rake`** - Rake task wrapper
- **`:rspec`** - RSpec test runner

Each template has a corresponding test file in `test/test_<template>.rb`.

### Other

- **`share/`** - Shell scripts for bash completion setup/removal
- **`core-docs/`** - Generated directory; toys-core source copied here for YARD cross-referencing (not checked in)

## Testing

- Tests in `test/` use Minitest spec style (`describe`/`it`) with assertions
- Test fixtures in `test-data/` organized by template (minitest-cases, rake-dirs, rspec-cases, etc.)
- Builtin tool tests live in `builtins/.test/` and `builtins/system/.test/`, run separately via `test-builtins`
- Integration tests are gated behind `TOYS_TEST_INTEGRATION=true`
- The YARD build copies toys-core source into `core-docs/` for cross-referencing; the `yardoc-test` tool verifies that optimized and unoptimized builds produce identical output
