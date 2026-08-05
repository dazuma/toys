# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

toys-release is a Ruby library release automation system using GitHub Actions and Toys. It interprets conventional commit messages to automate changelog generation and version bumping based on semantic versioning, and uses GitHub pull requests for release approval. It can tag GitHub releases, push gems to RubyGems, and publish documentation to gh-pages. It depends on `toys-core ~> 0.20`.

## Development Commands

From within the `toys-release` directory, use `toys` to run CI/test tasks specific to this gem. For example:

```bash
toys ci --only --current  # Run all CI tasks for this gem
toys test                 # Run just the tests for this gem, omitting integration tests
toys test --integration   # Run just the tests for this gem, including integration tests
toys rubocop              # Run just RuboCop for this gem
```

To run individual test files directly, pass them as positional command line arguments. This must be run from within the `toys-release` gem directory, and will not work from the repository root.

```bash
toys test toys/.test/test_change_set.rb toys/.test/test_repository.rb   # Run only the tests in the given files
```

Tests run via the built-in `system test` tool pointing at the `toys/` directory, which discovers tests in `toys/.test/`.

## Project Layout

This gem has an unusual layout compared to typical Ruby gems. The library code is split across two locations:

- **`lib/`** - Only contains `toys/release/version.rb` (the gem version constant). This is the gem's `require_paths` entry.
- **`toys/`** - Contains all the Toys tool definitions and the actual library code:
  - **`toys/.lib/toys/release/`** - The main library classes (loaded via Toys' `.lib` directory convention, not via `require_paths`)
  - **`toys/.test/`** - All tests and test fixtures
  - **`toys/.data/templates/`** - ERB templates for GitHub Actions workflows and gh-pages
  - Tool files at `toys/*.rb` - The release tools themselves

This layout means the library classes are loaded by Toys' `.lib` auto-load mechanism rather than standard `require`. Tests manually add `toys/.lib` to `$LOAD_PATH` in their helper.

## Testing

- Tests live in `toys/.test/` using Minitest spec style with assertions
- Test helper (`toys/.test/helper.rb`) manually adds `toys/.lib` to `$LOAD_PATH` and requires all library classes
- Test fixtures in `toys/.test/.data/` (changelog files, version files, directory structures)
- Tests use mock objects for `EnvironmentUtils` and `Repository` to avoid Git/GitHub interactions
- On GitHub CI, the test helper automatically unshallows the repo for commit history tests
