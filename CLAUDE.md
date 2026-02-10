# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Toys is a configurable command line tool framework for Ruby. It is a **monorepo** containing multiple gems:

- **toys-core** (`toys-core/`) - The framework library providing the DSL, argument parsing, middleware, and tool loading infrastructure
- **toys** (`toys/`) - The main CLI executable gem that depends on toys-core
- **toys-release** (`toys-release/`) - Release automation system for GitHub Actions
- **common-tools** (`common-tools/`) - Shared development tooling helpers (not a gem)

## Development Commands

Toys is **self-hosted** — it uses itself for all build, test, and CI tasks via the `./toys-dev` bootstrap script (which runs the local development copy).

```bash
./toys-dev test                      # Run all tests across all gems
./toys-dev rubocop                   # Run RuboCop for all gems
./toys-dev ci                        # Run full CI (tests, rubocop, yardoc, build)
./toys-dev yardoc                    # Generate YARD documentation
./toys-dev build                     # Build gems
```

Use `--only` to target specific gems or CI jobs. See each subdirectory's CLAUDE.md for gem-specific commands.

Use `--help` for detailed usage information about any `toys-dev` development command. For example `./toys-dev test --help`.

## Code Style

- Ruby 2.7+ target
- Double-quoted strings (`Style/StringLiterals: double_quotes`)
- Trailing commas in multiline arrays and hashes
- Bracket-style symbol and word arrays (`[:foo, :bar]` not `%i[foo bar]`)
- Max line length: 120
- `Style/DocumentationMethod: Enabled` — public methods require YARD docs
- Tests use Minitest spec style with assertions (not expectations)

## Testing

- Minitest spec style: `describe`/`it` blocks with `assert_*` assertions (not expectations)
- Test files follow the `test_*.rb` naming convention
- Integration tests are gated behind `TOYS_TEST_INTEGRATION=true` environment variable

## General coding instructions

- Use red-green test-driven development when making changes, unless instructed otherwise.
- Conventional Commits format required (`fix:`, `feat:`, `docs:`, etc.)
- Avoid making changes to files under `toys-release/` in the same commit as changes to files under either `toys/` or `toys-core/`.
