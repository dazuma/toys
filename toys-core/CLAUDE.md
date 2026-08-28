# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

toys-core is the framework library underlying the Toys CLI. It provides the DSL, argument parsing, tool loading, middleware pipeline, and execution context for building command line tools in Ruby. It has minimal dependencies (only `logger` from stdlib).

## Development Commands

From within the `toys-core` directory, use `toys` to run CI/test tasks specific to this gem. For example:

```bash
toys ci --only --current  # Run all CI tasks for this gem
toys test                 # Run just tests for this gem, omitting integration tests
toys test --integration   # Run just tests for this gem, including integration tests
toys rubocop              # Run just RuboCop for this gem
```

To run individual test files directly, pass them as positional command line arguments. This must be run from within the `toys-core` gem directory, and will not work from the repository root.

```bash
toys test test/test_cli.rb test/test_loader.rb   # Run only the tests in the given files
toys test --integration test/test_cli.rb test/test_loader.rb   # Include integration tests
```

To exercise a DSL or argument-parsing change end-to-end, beyond the unit tests, create a scratch directory containing a `.toys.rb` that defines a test tool, and run the repository's `./toys-dev` script from that directory by absolute path.

## Source Architecture

The classes under `lib/toys/` are organized into layers (execution, loading, definition, support). The layer map, and the one intentional upward dependency, are documented in the `Toys` module comment at the top of `lib/toys-core.rb`.

## Testing

- Tests are in `test/` using Minitest spec style (`describe`/`it`) with assertions (not expectations)
- Test helper: `test/helper.rb` provides `Toys::TestHelper`, mixed into all tests, with `isolate_ruby` for subprocess testing and `assert_expanded_path` for asserting an expanded absolute path portably (Windows prepends a drive letter)
- Test fixtures: `test-data/` contains tool definitions and gem fixtures organized by test scenario
- Subdirectories `test/middleware/`, `test/mixins/`, `test/utils/` mirror the source structure
- Integration tests are gated behind `TOYS_TEST_INTEGRATION=true`
- YARD docs must build with zero warnings and full coverage (`--fail-on-warning`, `--fail-on-undocumented-objects`)

## Key Design Patterns

- **Lazy loading**: Tools are defined lazily — the Loader only parses `.toys.rb` files when a tool is actually requested
- **Middleware pipeline**: Tool execution is wrapped in a middleware chain (similar to Rack). Middleware handles help display, usage errors, verbosity flags, etc.
- **DSL evaluation**: `.toys.rb` files are evaluated in the context of `DSL::Tool`, which writes into a `ToolDefinition`
- **ModuleLookup**: Mixins, middleware, and templates are resolved by symbolic name via `ModuleLookup`, which maps names to Ruby modules/classes
