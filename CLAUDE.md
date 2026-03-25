# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Toys is a configurable command line tool framework for Ruby. It is a **monorepo** containing multiple gems:

- **toys-core** (`toys-core/`) - The framework library providing the DSL, argument parsing, middleware, and tool loading infrastructure. Used by the `toys` gem, but can also be used to write a standalone executable.
- **toys** (`toys/`) - The main CLI executable gem that provides the `toys` executable, also providing a set of common tool templates and some built-in tools. Depends on toys-core.
- **toys-release** (`toys-release/`) - Release automation system for GitHub Actions.
- **toys-ci** (`toys-ci/`) - CI tool library providing a mixin and template for implementing CI jobs in Toys. Depends on toys-core.
- **common-tools** (`common-tools/`) - Shared development tooling helpers (not a gem).

## Development Commands

Toys is **self-hosted** — it uses itself for all build, test, and CI tasks. The Toys files in this repository redirect all `toys` invocations to use the local development code instead of the installed toys gem. (You can also run the `./toys-dev` local bootstrap script explicitly, but it is easier simply to run `toys` and let the Toys files do the redirecting for you.)

To run CI/test tasks across all gems, run `toys` from the repository root. For example:

```bash
toys ci                  # Run all CI tasks (test/rubocop/build/yardoc) for all gems
toys test                # Run just tests for all gems, omitting integration tests
toys test --integration  # Run just tests for all gems, including integration tests
toys rubocop             # Run just RuboCop for all gems
```

To run only the CI/test tasks for a specific gem, run toys from that gem's subdirectory. See each gem subdirectory's `CLAUDE.md` for gem-specific examples. In particular, if you want to specify individual test files, you *must* run `toys` from a gem subdirectory; test file specification does not work from the repository root. For example:

```bash
cd toys-core && toys test test/test_dsl.rb
```

Pass the `--help` flag to any toys command to display a manpage describing all available options. For example:

```bash
toys ci --help  # Display a manpage showing all available options for toys ci
```

## Code Style

- Ruby 2.7+ target
- Double-quoted strings (`Style/StringLiterals: double_quotes`)
- Trailing commas in multiline arrays and hashes
- Bracket-style symbol and word arrays (`[:foo, :bar]` not `%i[foo bar]`)
- Max line length: 120
- `Style/DocumentationMethod: Enabled` — public methods require YARD docs
- Tests use Minitest spec style with assertions (not expectations)
- Top-level constants must be prefixed with `::` (e.g. `::File`, `::Regexp`, `::Gem::Version`) to avoid ambiguous resolution within nested namespaces. Relative constants defined within the current namespace should not be prefixed. Note that Kernel method calls such as `Array(x)`, `Integer(x)`, `Float(x)` look like constants but are not and do not get the prefix.

## Testing

- Minitest spec style: `describe`/`it` blocks with `assert_*` assertions (not expectations)
- Test files follow the `test_*.rb` naming convention
- Integration tests are gated behind `TOYS_TEST_INTEGRATION=true` environment variable

## General coding instructions

- Unless instructed otherwise, always use red-green test-driven development when making code changes. For each step in a coding task, first write tests and confirm they fail. Then write code to make the tests pass.
- Unless instructed otherwise, always git commit after a step is complete and the tests and rubocop both pass.
- Conventional Commits format required (`fix:`, `feat:`, `docs:`, etc.)
- Avoid making changes to multiple gems in the same commit.
- Prefer Ruby for any one-off scripts you need to write as part of your work.
