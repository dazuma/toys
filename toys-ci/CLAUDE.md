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

## Testing

- Tests live in `test/` using Minitest spec style (`describe`/`it`) with `assert_*` assertions
- Tests construct a `Toys::CLI` directly and invoke tools programmatically via `cli.run`
- `Toys::TestHelper.stub_changed_files` stubs `exec` on a tool context to simulate git diff output, enabling tests of trigger-path filtering without a real git repo
- Test fixtures live in `test-data/`
