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

### Running Tests

```bash
./toys-dev test                      # Run all tests
./toys-dev test --only --core        # Test toys-core only
./toys-dev test --only --toys        # Test toys gem only
./toys-dev test --only --release     # Test toys-release gem only
./toys-dev test --only --builtins    # Test builtin commands only
./toys-dev test --only --tools       # Test common-tools only
./toys-dev test --integration        # Include integration tests
```

Individual test files can be run directly with Ruby:
```bash
ruby -Itoys-core/lib -Itoys-core/test toys-core/test/test_cli.rb
ruby -Itoys/lib -Itoys-core/lib -Itoys/test toys/test/test_lookup.rb
```

### Linting

```bash
./toys-dev rubocop                   # Run RuboCop for all gems
./toys-dev rubocop --only --core     # RuboCop for toys-core only
./toys-dev rubocop --only --toys     # RuboCop for toys only
./toys-dev rubocop --only --release  # RuboCop for toys-release only
./toys-dev rubocop --only --root     # RuboCop for repo tools/common-tools
```

### Full CI

```bash
./toys-dev ci                        # Run all CI jobs (tests, rubocop, yardoc, build)
./toys-dev ci --only --test-core     # Run a specific CI job
./toys-dev ci --only --rubocop-all   # Run all rubocop jobs
./toys-dev ci --only --test-all      # Run all test jobs
```

### Other Commands

```bash
./toys-dev yardoc                    # Generate YARD documentation
./toys-dev build                     # Build gems
```

## Architecture

### Core Framework (toys-core)

The key classes in `toys-core/lib/toys/`:

- **`CLI`** (`cli.rb`) - Main entry point. Configures middleware stacks, sets up the loader, and runs tools.
- **`Loader`** (`loader.rb`) - Discovers and loads `.toys.rb` files from directories, gems, and blocks. Manages tool namespaces.
- **`ToolDefinition`** (`tool_definition.rb`) - The largest file (~52KB). Represents a complete tool definition including flags, args, execution logic, and metadata.
- **`DSL::Tool`** (`dsl/tool.rb`) - The DSL class that tool authors use inside `.toys.rb` files to define tools (flags, args, descriptions, `def run`, etc.).
- **`ArgParser`** (`arg_parser.rb`) - Parses command line arguments against a tool definition.
- **`Context`** (`context.rb`) - Runtime execution context available as `self` inside a tool's `run` method.
- **`Middleware`** (`middleware.rb`) - Middleware pipeline wrapping tool execution (help display, verbosity flags, usage errors, etc.).
- **`Settings`** (`settings.rb`) - Type-safe hierarchical configuration system.
- **`SourceInfo`** (`source_info.rb`) - Tracks where tool definitions come from (files, directories, gems).

### Standard Mixins (`standard_mixins/`)

Mixins that tools can `include`: `:exec` (subprocess execution), `:terminal` (terminal I/O), `:fileutils`, `:bundler`, `:gems`, `:git_cache`, `:highline`, `:pager`, `:xdg`.

### Standard Middleware (`standard_middleware/`)

Built-in middleware: `show_help`, `handle_usage_errors`, `set_default_descriptions`, `add_verbosity_flags`, `show_root_version`, `apply_config`.

### Toys CLI (`toys/`)

- `bin/toys` - Executable entry point
- `lib/toys/standard_cli.rb` - Configures the CLI with default middleware stack and built-in tools
- `builtins/` - Built-in tools (e.g., `do` for chaining commands, `system` namespace for version/completion)

### Templates

Reusable tool generators available via `expand`: `:clean`, `:minitest`, `:rubocop`, `:yardoc`, `:rdoc`, `:gem_build`, `:rake`, `:toys_ci`.

## Code Style

- Ruby 2.7+ target
- Double-quoted strings (`Style/StringLiterals: double_quotes`)
- Trailing commas in multiline arrays and hashes
- Bracket-style symbol and word arrays (`[:foo, :bar]` not `%i[foo bar]`)
- Max line length: 120
- `Style/DocumentationMethod: Enabled` — public methods require YARD docs
- Tests use Minitest spec style with assertions (not expectations)

## Testing Notes

- Test files follow the `test_*.rb` naming convention
- Tests use `describe`/`it` blocks (Minitest spec) with `assert_*` assertions
- Test data/fixtures live in `test-data/` directories within each gem
- Integration tests are gated behind `TOYS_TEST_INTEGRATION=true` environment variable
