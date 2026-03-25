# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

toys-ci is a Ruby gem providing a CI tool library for Toys. It supplies a Toys mixin (`Toys::CI::Mixin`) and a Toys template (`Toys::CI::Template`) that make it easy to implement CI tools that run a set of jobs (other tools or shell commands), track pass/fail/skip status, support fail-fast behavior, and filter jobs based on changed files. It depends on `toys-core ~> 0.20`.

## Development Commands

From within the `toys-ci` directory, use `toys` to run CI/test tasks specific to this gem. For example:

```bash
toys ci --only --current  # Run all CI tasks for this gem
toys test                 # Run just the tests for this gem, omitting integration tests
toys test --integration   # Run just the tests for this gem, including integration tests
toys rubocop              # Run just RuboCop for this gem
```

To run individual test files directly, pass them as positional command line arguments. This must be run from within the `toys-ci` gem directory, and will not work from the repository root.

```bash
toys test test/test_mixin.rb test/test_template.rb  # Run only the tests in the given files
```

Tests are discovered in `test/` using the `test_*.rb` naming convention.

## Project Layout

This gem uses a conventional Ruby gem layout:

- **`lib/toys-ci.rb`** - Main entry point; requires `mixin`, `template`, and `version`
- **`lib/toys/ci/mixin.rb`** - `Toys::CI::Mixin` — low-level mixin for implementing CI tools
- **`lib/toys/ci/template.rb`** - `Toys::CI::Template` — high-level template that generates a complete CI tool with flags and a `run` method
- **`lib/toys/ci/version.rb`** - Gem version constant
- **`test/`** - All tests and test fixtures
  - **`test/test_mixin.rb`** - Tests for `Toys::CI::Mixin`
  - **`test/test_template.rb`** - Tests for `Toys::CI::Template`
  - **`test/helper.rb`** - Test helper; defines `Toys::TestHelper.stub_changed_files` for mocking git diff output
- **`test-data/`** - Test fixtures
  - **`test-data/basic-tools/.toys.rb`** - Minimal Toys tool definitions (`foo`, `bar`) used in tests
  - **`test-data/push-event.json`** - Sample GitHub push event payload for testing
  - **`test-data/pr-event.json`** - Sample GitHub pull_request event payload for testing

## Architecture

### `Toys::CI::Mixin`

A lower-level mixin that provides methods for implementing CI tools. Users include this mixin, write their own `run` method, and call:

- `toys_ci_init` — Initialize state; optionally enable fail-fast and/or set a git ref to filter changed files
- `toys_ci_tool_job(name, tool, ...)` — Run a job implemented by a Toys tool
- `toys_ci_cmd_job(name, cmd, ...)` — Run a job implemented by an external command
- `toys_ci_job(name, ...) { ... }` — Run a job implemented by a block
- `toys_ci_report_results` — Print the summary and exit (or return the exit code)
- `toys_ci_github_event_base_sha(event_name, event_path)` — Parse a GitHub event JSON file to extract a change base SHA

Jobs can specify `trigger_paths:` to be skipped when no matching files have changed since the base ref. The mixin uses the `:exec` and `:terminal` Toys mixins internally.

### `Toys::CI::Template`

A higher-level template that generates a complete CI tool (including the `run` method and all flags) by expanding into the current tool. Uses `Toys::CI::Mixin` under the hood.

Key configuration methods:
- `tool_job(name, tool, flag:, trigger_paths:, ...)` — Add a tool-based job
- `cmd_job(name, cmd, flag:, trigger_paths:, ...)` — Add a command-based job
- `job(name, flag:, trigger_paths:) { ... }` — Add a block-based job
- `collection(name, flag, job_flags)` — Group jobs into a named collection
- `before_run { ... }` — Register a block to run before CI jobs start
- `all_flag=` / `only_flag=` / `jobs_disabled_by_default=` — Control default job enablement
- `fail_fast_flag=` / `fail_fast_default=` — Configure fail-fast behavior
- `base_ref_flag=` — Add a `--base-ref` flag for filtering by changed files
- `include_github_event_flags` — Add `--github-event-name` and `--github-event-path` flags

## Testing

- Tests live in `test/` using Minitest spec style (`describe`/`it`) with `assert_*` assertions
- Tests construct a `Toys::CLI` directly and invoke tools programmatically via `cli.run`
- `Toys::TestHelper.stub_changed_files` stubs `exec` on a tool context to simulate git diff output, enabling tests of trigger-path filtering without a real git repo
- Test fixtures live in `test-data/`
