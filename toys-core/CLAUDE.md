# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

toys-core is the framework library underlying the Toys CLI. It provides the DSL, argument parsing, tool loading, middleware pipeline, and execution context for building command line tools in Ruby. It has minimal dependencies (only `logger` from stdlib).

## Development Commands

From the **repository root**, use the self-hosted `./toys-dev` bootstrap script:

```bash
./toys-dev test --only --core         # Run toys-core tests
./toys-dev rubocop --only --core      # Run RuboCop for toys-core
./toys-dev ci --only --test-core      # Run toys-core tests via CI runner
./toys-dev ci --only --rubocop-core   # Run toys-core RuboCop via CI runner
./toys-dev ci --only --yard-core      # Run YARD doc generation check
```

From **within the toys-core directory**, using the toys-dev script:

```bash
../toys-dev test                      # Run all toys-core tests
../toys-dev test --integration        # Include integration tests
../toys-dev rubocop                   # Run RuboCop
../toys-dev yardoc                    # Generate YARD docs (fails on warnings/undocumented objects)
../toys-dev build                     # Build the gem
```

Running individual test files directly:

```bash
ruby -Ilib -Itest test/test_cli.rb
ruby -Ilib -Itest test/test_loader.rb
```

## Source Architecture

All source lives under `lib/toys/`. The framework has a layered architecture:

### Tool Definition Layer

- **`tool_definition.rb`** (~52KB) - The central class. A `ToolDefinition` holds everything about a tool: flags, positional args, execution blocks, descriptions, middleware, mixins, source info, and settings. Most other classes feed into or read from this.
- **`flag.rb`** - Models flag definitions (e.g., `--verbose`, `-n VALUE`). Handles flag syntax parsing, default values, acceptors, and flag resolution.
- **`flag_group.rb`** - Groups flags with constraints (required, exactly one, at most one, at least one).
- **`positional_arg.rb`** - Models required, optional, and remaining positional arguments.
- **`acceptor.rb`** - Validates and converts string arguments. Built-in acceptors for common types (Integer, Float, etc.) plus custom regex/block-based acceptors.

### DSL Layer (`dsl/`)

- **`dsl/tool.rb`** - The main DSL module users interact with in `.toys.rb` files. Provides `desc`, `flag`, `required_arg`, `optional_arg`, `remaining_args`, `include` (for mixins), `expand` (for templates), `tool` (for subtools), and `def run`.
- **`dsl/flag.rb`** - DSL for configuring individual flags within a block.
- **`dsl/flag_group.rb`** - DSL for flag group blocks.
- **`dsl/positional_arg.rb`** - DSL for configuring positional args within a block.
- **`dsl/base.rb`** - Base DSL for top-level `.toys.rb` files (delegating to Tool).
- **`dsl/internal.rb`** - Internal DSL support.

### Loading & Resolution Layer

- **`loader.rb`** (~35KB) - Discovers and loads `.toys.rb` files from directories, gems, and blocks. Manages the tool namespace hierarchy and lazy-loads tool definitions on demand.
- **`source_info.rb`** - Tracks provenance of tool definitions (which file, directory, or gem they came from). Provides access to data directories and context directories.
- **`input_file.rb`** - Handles reading and evaluating `.toys.rb` input files.

### Execution Layer

- **`cli.rb`** (~28KB) - The main entry point. Configures the loader, middleware stack, and mixin/template/middleware lookups. Orchestrates parsing and running tools.
- **`arg_parser.rb`** (~20KB) - Parses command line arguments against a tool definition. Handles flags, positional args, and subtool dispatch.
- **`context.rb`** - The runtime context (`self` inside a tool's `run` method). Provides access to parsed arguments, options, and exit codes.
- **`middleware.rb`** - Middleware pipeline wrapping tool execution. Each middleware can intercept before/after tool run.
- **`completion.rb`** - Shell tab-completion support.

### Support Layer

- **`settings.rb`** (~30KB) - Type-safe hierarchical configuration system with field definitions and group nesting.
- **`mixin.rb`** - Module mixin infrastructure for tools.
- **`template.rb`** - Template infrastructure for reusable tool generators.
- **`module_lookup.rb`** - Name-to-module resolution for mixins, middleware, and templates.
- **`errors.rb`** - Custom exception classes.
- **`wrappable_string.rb`** - Terminal-aware text wrapping.
- **`compat.rb`** - Ruby version compatibility shims.

### Utils (`utils/`)

Utility classes used by the framework and available to tool authors:

- **`exec.rb`** (~54KB) - Subprocess execution with streaming I/O, capture, and controller support.
- **`git_cache.rb`** - Git repository caching for remote sources.
- **`help_text.rb`** - Generates formatted help text for tools.
- **`terminal.rb`** - Terminal I/O with styling, spinners, and prompts.
- **`pager.rb`** - Pager support (less/more).
- **`standard_ui.rb`** - Standard UI patterns for tools.
- **`gems.rb`** - On-demand gem activation and installation.
- **`xdg.rb`** - XDG Base Directory support.
- **`completion_engine.rb`** - Drives shell completion.

### Standard Mixins (`standard_mixins/`)

Mixins that tools include via `include :mixin_name`: `:exec`, `:terminal`, `:fileutils`, `:bundler`, `:gems`, `:git_cache`, `:highline`, `:pager`, `:xdg`.

### Standard Middleware (`standard_middleware/`)

Built-in middleware: `show_help`, `handle_usage_errors`, `set_default_descriptions`, `add_verbosity_flags`, `show_root_version`, `apply_config`.

## Testing

- Tests are in `test/` using Minitest spec style (`describe`/`it`) with assertions (not expectations)
- Test helper: `test/helper.rb` provides `Toys::TestHelper` with `isolate_ruby` for subprocess testing
- Test fixtures: `test-data/` contains tool definitions and gem fixtures organized by test scenario
- Subdirectories `test/middleware/`, `test/mixins/`, `test/settings/`, `test/utils/` mirror the source structure
- Integration tests are gated behind `TOYS_TEST_INTEGRATION=true`
- YARD docs must build with zero warnings and full coverage (`--fail-on-warning`, `--fail-on-undocumented-objects`)

## Key Design Patterns

- **Lazy loading**: Tools are defined lazily — the Loader only parses `.toys.rb` files when a tool is actually requested
- **Middleware pipeline**: Tool execution is wrapped in a middleware chain (similar to Rack). Middleware handles help display, usage errors, verbosity flags, etc.
- **DSL evaluation**: `.toys.rb` files are evaluated in the context of `DSL::Tool`, which writes into a `ToolDefinition`
- **ModuleLookup**: Mixins, middleware, and templates are resolved by symbolic name via `ModuleLookup`, which maps names to Ruby modules/classes
