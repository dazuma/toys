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

## Source Notes

- `lib/toys/version.rb` defines `Toys::VERSION`, which must match toys-core's `Toys::Core::VERSION`.
- `core-docs/` is a generated directory and is not checked in.

## Testing

- Tests in `test/` use Minitest spec style (`describe`/`it`) with assertions
- Test fixtures in `test-data/` organized by template (minitest-cases, rake-dirs, rspec-cases, etc.)
- Builtin tool tests live in `builtins/.test/` and `builtins/system/.test/`, run separately via `test-builtins`
- Unlike `test`, `test-builtins` runs in a process with no Bundler and without the `toys` or `toys-core` gems activated. A test that needs an activatable gem must register a synthetic `Gem::Specification` (see `builtins/.test/test_do.rb`)
- RuboCop does not cover `builtins/.test/**`, so builtin test files are not linted
- Integration tests are gated behind `TOYS_TEST_INTEGRATION=true`
- The YARD build copies toys-core source into `core-docs/` for cross-referencing; the `yardoc-test` tool verifies that optimized and unoptimized builds produce identical output
