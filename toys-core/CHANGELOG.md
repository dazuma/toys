# Release History

### v0.19.0 / 2025-12-22

Compatibility update for Ruby 4.0, including:

* The logger gem is now an explicit dependency
* Calling a tool via exec no longer disables rubygems
* Bundler integration does a better job of cleaning up temporary lockfiles under bundler 4

Additionally, this release includes updates to readmes and users guides

### v0.18.0 / 2025-12-05

* ADDED: The load_gem directive can now take version requirements as positional arguments

### v0.17.2 / 2025-11-30

* FIXED: Minor formatting fix in the gem install prompt
* DOCS: Fixed minor typos in readme files

### v0.17.1 / 2025-11-07

* FIXED: Rolled back dependency on the logger gem because it is causing some issues with bundler integration

### v0.17.0 / 2025-11-07

Toys-Core 0.17 supports several significant new pieces of functionality:

* Support for loading tools from Rubygems. The load_gem directive loads tools from the "toys" directory in a gem, installing the gem if necessary. This makes it easy to distribute tools, securely and versioned, as gems.
* Flag handlers can now take an optional third argument, the entire options hash. This enables significantly more powerful behavior during flag parsing, such as letting flags affect the behavior of other flags.

Additional new features:

* When using the :gems mixin, you can now specify installation options such as on_missing not only when you include the mixin, but also when you declare the gem.
* Added support for an environment variable `TOYS_GIT_CACHE_WRITABLE` to disable the read-only behavior of git cache sources. This improves compatibility with environments that want to delete caches.

Other fixes and documentation:

* Added the standard logger gem to the toys-core dependencies to silence Ruby 3.5 warnings.
* Updated the user guide to cover new features and fix some internal links

### v0.16.0 / 2025-10-31

* ADDED: Updated minimum Ruby version to 2.7
* FIXED: ToolDefinition#includes_arguments no longer returns true if only default data is set

### v0.15.6 / 2024-05-15

* FIXED: Fixed argument parsing so flags with value delimited by "=" will support values containing newlines

### v0.15.5 / 2024-01-31

* FIXED: Fix for uri version mismatch error in certain bundler integration cases

### v0.15.4 / 2024-01-04

* FIXED: Fix error message when failing assertion of the toys version
* DOCS: Various documentation improvements

### v0.15.3 / 2023-10-31

* (No significant changes)

### v0.15.2 / 2023-10-17

* (No significant changes)

### v0.15.1 / 2023-10-15

* FIXED: Clean up some internal requires, which may improve performance with built-in gems.

### v0.15.0 / 2023-10-12

Toys-Core 0.15.0 is a major release that overhauls error and signal handling, cleans up some warts around entrypoint and method definition, and fixes a few long-standing issues.

Breaking changes:

* The default error_handler for Toys::CLI now simply reraises the unhandled exception out of Toys::CLI#run. This was done to simplify the default behavior and reduce its dependencies. Additionally, the Toys::CLI::DefaultErrorHandler class has been removed, and replaced with the Toys::CLI.default_error_handler class method implementing the simplified behavior. You can restore the old behavior by passing Toys::Utils::StandardUI#error_handler to the CLI.
* The default logger_factory for Toys::CLI now uses a simple bare-bones logger instead of the nicely formatted logger previously used as default. This was done to simplify the default behavior and reduce its dependencies. You can restore the old behavior by passing Toys::Utils::StandardUI#logger_factory to the CLI.
* The Toys::CLI::DefaultCompletion class has been removed, and replaced with the Toys::CLI.default_completion class method.
* Passing a proc to Toys::ToolDefinition#run_handler= now sets the run handler directly to the proc rather than defining the run method.
* The default algorithm for determining whether flags and arguments add methods now allows overriding of methods of Toys::Context and any other included modules, but prevents collisions with private methods defined in the tool. (It continues to prevent overriding of public methods of Object and BasicObject.)

New functionality:

* New DSL directive on_signal lets tools provide signal handlers.
* New utility Toys::Utils::StandardUI implements the error handling and logger formatting used by the toys executable. (These implementations were moved out of the Toys::CLI base class.)
* Toys::ToolDefinition provides methods for managing signal handlers.
* Passing a symbol to Toys::ToolDefinition#run_handler= can set the run entrypoint to a method other than "run".
* Flags and arguments can be configured explicitly to add methods or not add methods, overriding the default behavior.

Fixes and other changes:

* The Bundler integration prevents Bundler from attempting to self-update to the version specified in a lockfile (which would often cause problems when Bundler is called from Toys).
* If a missing delegate or a delegation loop is detected, ToolDefinitionError is raised instead of RuntimeError.
* Some cleanup of various mixins to prevent issues if their methods ever get overridden.
* Progress on the toys-core user guide. It's not yet complete, but getting closer.
* Various improvements and clarifications in the reference documentation.

### v0.14.7 / 2023-07-19

* FIXED: Fixed an exception when passing a non-string to puts in the terminal mixin

### v0.14.6 / 2023-06-29

* FIXED: Fixed a GitCache exception when loading a repository containing a broken symlink

### v0.14.5 / 2023-03-20

* FIXED: Rescue broken pipe errors by default when running a pager

### v0.14.4 / 2023-01-23

* FIXED: Fixed missing require when "toys/utils/xdg" or "toys/utils/git_cache" is required without the rest of toys-core

### v0.14.3 / 2022-12-29

* FIXED: Exit with a code -1 if a non-integer exit code is thrown
* FIXED: The sh command in the Exec utility returns -1 if the exit code cannot be determined
* FIXED: Update Bundler integration to support Bundler 2.4 and Ruby 3.2
* FIXED: Fix for installing bundler on older Rubies
* FIXED: Fixed XDG defaults on JRuby 9.4

### v0.14.2 / 2022-10-09

* ADDED: The tool directive supports the delegate_relative argument, as a preferred alternative over alias_tool.
* FIXED: The toys file reference now properly appears in error messages on Ruby 3.1.
* FIXED: Error messages show the correct toys file line number on TruffleRuby.
* FIXED: Inspect strings for tool classes are less opaque and include the tool name.
* FIXED: The presence of an acceptor forces an ambiguous flag to take a value rather than erroring.

### v0.14.1 / 2022-10-03

* (No significant changes)

### v0.14.0 / 2022-10-03

Toys-Core 0.14.0 is a major release with pager support, support for tees and pipes in the Exec utility, some cleanup of the behavior of Acceptors, and other improvements.

Fixes that are potentially breaking:

* Disallowed acceptors on flags that are explicitly boolean.
* Acceptors no longer sometimes apply to the boolean setting of a flag with an optional value.

New functionality:

* Implemented a utility class and mixin for output pagers.
* Builtin commands that display data can format as either YAML or JSON.
* The Exec utility and mixin can tee (i.e. duplicate and split) output streams.
* The Exec utility and mixin can take pipes as input and output streams.
* The Exec mixin provides a `verbosity_flags` convenience method.
* `Loader#list_subtools` takes separate arguments for filtering namespaces and non-runnable tools

Fixes:

* Contents of preload directories are loaded in sorted order.
* Removed some potential deadlocks if a `Toys::Loader` is accessed from multiple threads
* Various clarifications, fixes, and updates to the users guide and documentation.

### v0.13.1 / 2022-03-01

* FIXED: Toys::Utils::Gems no longer fails to install a bundle if it had locked to a different version of a builtin gem

### v0.13.0 / 2022-02-08

Toys-Core 0.13.0 is a major release with significant improvements to the git cache, along with compatibility improvements and bug fixes.

New functionality:

* The `load_git` directive and the underlying `Toys::Utils::GitCache` class now support updating from git based on cache age.
* The `Toys::Utils::GitCache` class supports copying git content into a provided directory, querying repo information, and deleting cache data.
* The `Toys::Utils::GitCache` class makes files read-only, to help prevent clients from interfering with one another.
* The `:terminal` mixin and the underlying `Toys::Utils::Terminal` class now honor the `NO_COLOR` environment variable.
* Added `Toys::CLI#load_tool`, which is useful for testing tools.

Fixes and compatibility updates:

* Bundler install/updates are now spawned in subprocesses for compatibility with bundler 2.3. The bundler integration also now requires bundler 2.2 or later.
* The `exec_tool` and `exec_proc` methods in the `:exec` mixin now log their execution in the same way as other exec functions.
* Minor compatibility fixes to provide partial support for TruffleRuby.

Other notes:

* The internal GitCache representation has changed significantly to support additional features and improve robustness and performance. This will force existing caches to update, but should not break existing usage.

### v0.12.2 / 2021-08-30

* FIXED: Tool context inspect string is no longer overwhelmingly long
* FIXED: Fixed an exception in GitCache when updating a changed ref

### v0.12.1 / 2021-08-17

* FIXED: Fixed a regression in 0.12.0 where bundler could use the wrong Gemfile if you set a custom context directory

### v0.12.0 / 2021-08-05

Toys-Core 0.12.0 is a major release with significant new features and bug fixes, and a few breaking interface changes. Additionally, this release now requires Ruby 2.4 or later.

Breaking interface changes:

* The Toys::Tool class has been renamed Toys::ToolDefinition so that the old name can be used for class-based tool definition.
* Tool definition now raises ToolDefinitionError if whitespace, control characters, or certain punctuation are used in a tool name.
* Toys::Loader#add_path no longer supports multiple paths. Use add_path_set instead.
* The "name" argument was renamed to "source_name" in Toys::Loader#add_block and Toys::CLI#add_config_block

New functionality:

* The DSL now supports a class-based tool definition syntax (in addition to the existing block-based syntax). Some users may prefer this new class-based style as more Ruby-like.
* You can now load tools from a remote git repository using the load_git directive.
* Whitespace is now automatically considered a name delimiter when defining tools.
* There is now an extensible settings mechanism to activate less-common tool behavior. Currently there is one setting, which causes subtools to inherit their parent's methods by default.
* The load directive can load into a new tool.
* Added a new utility class and mixin that provides XDG Base Directory information.
* Added a new utility class and mixin that provides cached access to remote git repos.
* The help text generator now supports splitting the subtool list by source.
* Loader and CLI methods that add tool configs now uniformly provide optional source_name and context_directory arguments.
* Toys::SourceInfo now supports getting the root ancestor and priority of a source.
* Toys::ToolDefinition now has a direct accessor for the source root. This is always set for a tool, even if it isn't marked as finished.

Fixes:

* Fixed some bundler integration issues that occurred when the bundle is being installed in a separate path such as a vendor directory.
* Toys::ContextualError now includes the full backtrace of the cause.
* Cleaned up some unused memory objects during tool loading and lookup.

### v0.11.5 / 2021-03-28

* BREAKING CHANGE: The exit_on_nonzero_status option to exec now exits on signals and failures to spawn, in addition to error codes.
* ADDED: Support retries in the bundler integration.
* FIXED: Fix a bundler 2.2 integration issue that fails install in certain cases when an update is needed.

### v0.11.4 / 2020-10-11

* FIXED: Doesn't modify bundler lockfiles when adding Toys to a bundle

### v0.11.3 / 2020-09-13

* FIXED: The Exec library recognizes the argv0 option, and logs it appropriately

### v0.11.2 / 2020-09-06

* FIXED: Fix a JRuby-specific race condition when capturing exec streams

### v0.11.1 / 2020-08-24

* DOCS: Minor documentation tweaks.

### v0.11.0 / 2020-08-21

* ADDED: The load path can be truncated using the `truncate_load_path!` directive.
* IMPROVED: Generated help for delegates now includes the information for the target tool, plus subtools of the delegate.
* IMPROVED: The `:bundler` mixin searches for `gems.rb` and `.gems.rb` in addition to `Gemfile`.
* IMPROVED: The `:budnler` mixin can load a specific Gemfile path.
* FIXED: The loader can now find data and lib directories at the root level of a Toys directory.
* FIXED: Exec::Result correctly reports processes that terminated due to signals.
* FIXED: Fixed a rare Exec capture failure that resulted from a race condition when closing streams.

### v0.10.5 / 2020-07-18

* IMPROVED: The bundler mixin silences bundler output during bundle setup.
* IMPROVED: The bundler mixin allows toys and toys-core to be in the Gemfile. It checks their version requirements against the running Toys version, and either adds the corret version to the bundle or raises IncompatibleToysError.
* IMPROVED: The bundler mixin automatically updates the bundle if install fails (typically because a transitive dependency has been explicitly updated.)
* FIXED: Some cases of transitive dependency handling by the bundler mixin.
* FIXED: Fixed a crash when computing suggestions, when running with a bundle on Ruby 2.6 or earlier.

### v0.10.4 / 2020-07-11

* IMPROVED: Bundler integration can now handle Toys itself being in the bundle, as long as the version requirements cover the running Toys version.
* IMPROVED: Passing `static: true` to the `:bundler` mixin installs the bundle at definition rather than execution time.

### v0.10.3 / 2020-07-04

* FIXED: The `exec_separate_tool` method in the `:exec` mixin no longer throws ENOEXEC on Windows.

### v0.10.2 / 2020-07-03

* FIXED: The load path no longer loses the toys and toys-core directories after a bundle install.

### v0.10.1 / 2020-03-07

* FIXED: Setting `:exit_on_nonzero_status` explicitly to false now works as expected.

### v0.10.0 / 2020-02-24

Functional changes:

* ADDED: `:bundler` mixin that installs and sets up a bundle for the tool
* ADDED: `bundle` method to `Toys::Utils::Gems` that performs bundler install and setup
* ADDED: `subtool_apply` directive which applies a block to all subtools.
* ADDED: Add `.lib` directories to the Ruby load path when executing a tool.
* ADDED: `toys_version?` and `toys_version!` directives that check against version requirements.
* ADDED: `exec_separate_tool` and `capture_separate_tool` methods in the `:exec` mixin, to support executing tools in a separate process without forking
* IMPROVED: `long_desc` directive can now read the description from a text file.
* IMPROVED: The `tool` directive can take delimited strings as tool names.
* IMPROVED: Subtool blocks aren't actually executed unless the tool is needed.
* CHANGED: Added `on_missing` and `on_conflict` arguments to `Toys::Utils::Gems` constructor (which also affects the `:gems` mixin), and deprecated `suppress_confirm` and `default_confirm`.

Internal interface changes:

* ADDED: `Toys::Tool#subtool_middleware_stack` allowing a tool to modify the middleware stack for its subtools.
* ADDED: The `Toys::Middleware::Stack` class represents a stack of middleware specs, and distinguishes the default set from those added afterward.
* ADDED: `Toys.executable_path` attribute allowing an executable to provide the executable for running tools separately.
* ADDED: `Toys::CLI` now has a `logger_factory` property, to generate separate loggers per tool execution.
* ADDED: `Toys::CLI` and `Toys::Loader` now let you set `:lib_dir_name`.
* IMPROVED: Toys-core no longer has a general dependency on rubygems. (Parts that do depend on rubygems, such as the `:gems` mixin, do an explicit `require "rubygems"`.) This makes it possible to write an executable with `ruby --disable=gems` which improves startup time.
* IMPROVED: Middleware objects no longer have to respond to all middleware methods. If a method is not implemented, it is simply considered a nop.
* IMPROVED: `Toys::Utils::Terminal` is now thread-safe.
* CHANGED: `Toys::Utils::Terminal#styled` is no longer mutable.
* CHANGED: `Toys::Tool#middleware_stack` renamed to `Toys::Tool#built_middleware` to clarify that it is an array of middleware objects rather than specs.
* CHANGED: `Toys::CLI.default_logger` removed and replaced with `Toys::CLI.default_logger_factory`. In general, global loggers for CLI are now discouraged because they are not thread-safe.
* CHANGED: `Toys::Loader` uses an internal monitor rather than including `MonitorMixin`.

### v0.9.4 / 2020-01-26

* FIXED: Crash in the loader when a non-ruby file appears in a toys directory

### v0.9.3 / 2020-01-05

* FIXED: `delegate_to` directive could crash if an overriding tool has already been defined.
* FIXED: A Ruby 2.7 warning when reporting a Toys file syntax error.

### v0.9.2 / 2020-01-03

* IMPROVED: Mixins can now take real keyword arguments, and will pass them on properly to `on_initialize` and `on_include` blocks.
* CHANGED: `Toys::Utils::Exec` and the `:exec` mixin methods now take real keyword arguments rather than an `opts` hash. This means you should use keywords (or the double-splat operator) to avoid a deprecation warning on Ruby 2.7.
* IMPROVED: `Toys::CLI#clone` can be passed keyword arguments to modify the configuration.
* IMPROVED: `Toys::Loader` is now thread-safe. This means it is now possible for a single `Toys::CLI` to run multiple tools in different threads.
* IMPROVED: There is now a class for middleware specs, making possible a nicer syntax for building a middleware stack.

### v0.9.1 / 2019-12-22

* IMPROVED: `delegate_to` and `alias_tool` can take symbols as well as strings.

### v0.9.0 / 2019-12-02

Functional changes:

* ADDED: The `delegate_to` directive causes the tool to delegate execution to another tool. This means it takes the same arguments and has the same execution behavior.
* ADDED: The `delegate_to` argument to the `tool` directive causes the tool to delegate to another tool. (Note: the `alias_tool` directive is now just shorthand for creating a tool with a delegate, and as such is mildly deprecated.)
* ADDED: The `current_tool` function can be called from the DSL to get the current `Toys::Tool` object.
* ADDED: The `:e` option is now an alias for `:exit_on_nonzero_status`.
* IMPROVED: `alias_tool` is now just shorthand for delegating. This means, aliases can now point to namespaces and will resolve subtools of their targets, and they now support tab completion and online help.
* IMPROVED: This release of Toys is now compatible with Ruby 2.7.0-preview3. It fixes some Ruby 2.7 specific bugs, and sanitizes keyword argument usage to eliminate Ruby 2.7 warnings.
* IMPROVED: JRuby is now supported for most operations. However, JRuby is generally not recommended because of JVM boot latency, lack of Kernel#fork support, and other issues.
* FIXED: The `tool` directive no longer crashes if no block is provided.

Internal interface changes:

* REMOVED: The `Toys::Alias` class has been removed, along with relevant functionality in `Toys::Loader` including `Toys::Loader#make_alias`. Use tool delegation instead.
* CHANGED: Positional arguments to middleware specs must now be wrapped in an array.
* CHANGED: The `Toys::ArgParser` constructor takes a `default_data` argument instead of `verbosity`.
* CHANGED: Version constant is now `Toys::Core::VERSION`.
* CHNAGED: The `flag` argument to `Toys::Flag::DefaultCompletion#initialize` is now a required keyword argument.
* ADDED: `Toys::Tool#delegate_to` causes the tool to delegate to another tool.
* ADDED: The `Toys::Context::Key::DELEGATED_FROM` key provides the delegating context, if any.

### v0.8.1 / 2019-11-19

* FIXED: Listing subtools would crash if a broken alias was present.
* DOCUMENTATION: Switched from redcarpet to kramdown, and tried to make some structural fixes.

### v0.8.0 / 2019-06-20

This is a major update with significant new features and a bunch of fixes. It also includes a significant amount of internal reorganization and cleanup, some of which resulted in backward incompatible changes. Basic use should not be affected. All signifiant features planned for beta are now implemented.

Major changes and features:

* CHANGED: Relicensed under the MIT License.
* CHANGED: Requires Ruby 2.3 or later.
* ADDED: Tab completion for bash. Added APIs and DSL constructs for tools to customize completions.
* ADDED: The usage error screen displays suggestions when an argument is misspelled. (Requires Ruby 2.4 or later.)
* ADDED: Tools can provide an interrupt handler and a custom usage error handler. Added appropriate APIs and DSL methods.
* ADDED: Tools can enforce that flags must be given before positional args, and can control whether partial flags are accepted.

Other notable changes:

* ADDED: Flag handlers can accept the symbolic names `:set` and `:push` for common cases.
* ADDED: Function and range based acceptors.
* ADDED: The `acceptor` directive takes an optional `type_desc` argument.
* ADDED: The `accept` directives under flag and positional arg blocks in the DSL can now take blocks and `type_desc` values.
* ADDED: Context keys `UNMATCHED_ARGS`, `UNMATCHED_POSITIONAL`, and `UNMATCHED_FLAGS` that provide arguments that were not handled during arg parsing.
* ADDED: The Exec util and mixin support specifying a callback for process results.
* ADDED: The Exec util and mixin provide a way to identify processes by name.
* CHANGED: Implemented custom argument parsing and custom implementations of the standard OptionParser acceptors, rather than relying on OptionParser itself. For the most part, OptionParser behavior is preserved, except in cases where there is clearly a bug.
* CHANGED: Flags create a short form flag by default if the name has one character.
* CHANGED: Flags with explicit value-less syntax are no longer given a value if they specify a default or an acceptor.
* CHANGED: Renamed the `TOOL_DEFINITION` context key to `TOOL`, and removed the `tool_definition` convenience method.
* CHANGED: Removed the `BINARY_NAME` and `LOADER` context keys, and removed the corresponding convenience methods. Get these values from the CLI if needed.
* CHANGED: Renamed the `USAGE_ERROR` context key to `USAGE_ERRORS`, and the corresponding convenience method to `usage_errors`. The value is now a (possibly empty) array of `Toys::ArgParser::UsageError` objects rather than a string that isn't machine-parseable.
* CHANGED: The help middleware no longer defines remaining_args on the root tool.
* CHANGED: Renamed `to_expand` to `on_expand` in template definitions.
* CHANGED: Renamed `to_initialize` to `on_initialize`, and `to_include` to `on_include` in mixin definitions.
* CHANGED: The CLI options `preload_directory_name` and `data_directory_name` renamed to `preload_dir_name` and `data_dir_name`.
* CHANGED: Default descriptions for flag groups is now handled by the `set_default_descriptions` middleware rather than hard-coded in FlagGroup.
* CHANGED: Exec reports failure to start processes in the result object rather than, e.g. raising ENOENT.
* IMPROVED: Default error handler no longer displays a stack trace if a tool is interrupted.
* IMPROVED: Error messages for flag groups are more complete.
* IMPROVED: All context data, including well-known data, is available to be modified by flags and args.
* FIXED: Flags with optional values are properly set to `true` (rather than left at `nil`) if no value is provided.
* FIXED: Acceptors no longer raise errors when run on missing optional values.
* FIXED: When reporting errors in toys files, the line number was off by 2.
* FIXED: The `--usage` help flag now honors `--all` and `--no-recursive`.
* FIXED: The terminal now handles nil streams, as advertised.

Changes to internal interfaces:

* General changes:
    * CHANGED: Renamed `Toys::Tool` to `Toys::Context`, and the `Keys` submodule to `Key`.
    * CHANGED: Moved the `ModuleLookup` and `WrappableString` out of the `Utils` module to be located directly under `Toys`. Other modules remain under `Utils`.  The remaining files under "toys/utils" must now be required explicitly. This directory is now specifically for modules that are not part of the "core" interface.
    * CHANGED: All the classes under `Toys::Definition` are now located directly under `Toys`. For example, `Toys::Definition::Tool` is now `Toys::Tool`.
    * CHANGED: Generally removed the term "definition" from interfaces. For example, an accessor method called `tool_definition` is now just called `tool`.
    * CHANGED: Renamed `Toys::DSL::Arg` to `Toys::DSL::PositionalArg`
    * CHANGED: Removed `Toys::Runner` and folded its functionality into `Toys::CLI`.
    * CHANGED: The fallback execution feature of the show_help middleware is implemented by catching an exception afterward rather than detecting non-runnable up front. This lets us remove the second copy of show_help from the middleware stack.
    * ADDED: Functionality dependent on Ruby version is kept in `Toys::Compat`.
* Changes related to the tool classes:
    * CHANGED: Moved `Toys::Definition::Tool` to `Toys::Tool`.
    * CHANGED: Removed the term "definition" from accessors. Specifically `flag_definitions` renamed to `flags`, `required_arg_definitions` renamed to `required_args`, `optional_arg_definitions` renamed to `optional_args`, `remaining_args_definition` renamed to `remaining_arg`, and `arg_definitions` renamed to `positional_args`.
    * CHANGED: Renamed `Tool#runnable=` to `Tool#run_handler=`.
    * CHANGED: `Tool#add_acceptor` takes the name as a separate argument, for consistency with `add_mixin` and `add_template`.
    * CHANGED: Removed `Tool#custom_acceptors` method.
    * CHANGED: Removed `Tool#resolve_acceptor` and replaced with `lookup_acceptor` which only looks up names.
    * CHANGED: Renamed `Tool#resolve_mixin` to `lookup_mixin` and `Tool#resolve_template` to `lookup_template`.
    * ADDED: Added `resolve_flag` method to look up flags by syntax.
    * ADDED: Accessor for interrupt handler.
    * ADDED: `enforce_flags_before_args` setting and `flags_before_args_enforced?` query.
    * ADDED: Completion accessor, and options to the various flag and positional arg methods to set their completion strategies.
    * ADDED: Added `Tool::DefaultCompletion` class.
    * IMPROVED: `add_mixin`, `add_template`, and `add_acceptor` support all the specs understood by their create methods.
* Changes related to the flag classes:
    * CHANGED: Moved `Toys::Definition::Flag` to `Toys::Flag`
    * CHANGED: `FlagSyntax` is now `Flag::Syntax`.
    * CHANGED: `Flag::Syntax#flag_style` now has values `:short` and `:long` instead of `"-"` and `"--"`.
    * CHANGED: `Flag#single_flag_syntax` renamed to `Flag#short_flag_syntax`, and `Flag#double_flag_syntax` renamed to `Flag#long_flag_syntax`.
    * CHANGED: Renamed `Flag#accept` to `Flag#acceptor` which now always returns an acceptor object (even for well-known acceptors such as `Integer`).
    * CHANGED: Removed `Flag#optparser_info` and replaced with `Flag#canonical_syntax_strings`.
    * ADDED: `Flag#create` class method providing a sane construction interface.
    * ADDED: `Flag#resolve` method to look up flag syntax.
    * ADDED: `Flag#completion` field.
    * ADDED: Added `Flag::Resolution` and `Flag::DefaultCompletion` classes.
* Changes related to the positional arg classes:
    * CHANGED: Moved `Toys::Definition::Arg` to `Toys::PositionalArg`.
    * CHANGED: Renamed `Arg#accept` to `PositionalArg#acceptor` which now always returns an acceptor object (even for well-known acceptors such as `Integer`).
    * ADDED: `PositionalArg#create` class method providing a sane construction interface.
    * ADDED: `PositionalArg#completion` field
* Changes related to the flag group classes:
    * CHANGED: Moved `Toys::Definition::FlagGroup` to `Toys::FlagGroup`
    * CHANGED: The base class is now `FlagGroup::Base` instead of `FlagGroup` itself.
    * ADDED: `FlagGroup#create` class method providing a sane construction interface.
* Changes related to acceptors:
    * CHANGED: Moved `Toys::Definition::Acceptor` to `Toys::Acceptor`
    * CHANGED: The base ciass is now `Acceptor::Base` instead of `Acceptor` itself.
    * CHANGED: Subclasses are now submodules under `Acceptor`. For example, moved `Toys::Definition::PatternAcceptor` to `Toys::Acceptor::Pattern`.
    * CHANGED: Replaced `name` field with separate `type_desc` and `well_known_spec` fields.
    * CHANGED: The base class no longer takes a conversion proc. It is always a no-op. `Acceptor::Pattern`, however, does take a converter so it can continue to handle custom OptionParser acceptors.
    * ADDED: Acceptors may define `suggestions` which returns results from did-you-mean.
    * ADDED: Simple acceptor (`Acceptor::Simple`) which uses a single function to validate and convert input.
    * ADDED: Range acceptor (`Acceptor::Range`) which validates against a range.
    * ADDED: Class methods `Acceptor.create` and `Acceptor.lookup_well_known`.

### v0.7.0 / 2019-01-23

* ADDED: Flag groups, which enforce policies around which flags are required.
* CHANGED: Flags within a group are sorted in help screens.
* CHANGED: Canonical flag within a flag definition is now the first rather than the last.

### v0.6.1 / 2019-01-07

* FIXED: The presence of aliases caused subtool listing to crash.

### v0.6.0 / 2018-10-22

* CHANGED: Replaced Toys::Definition::DataFinder with Toys::Definition::SourceInfo.
* CHANGED: Removed Toys::Definition#find_data. Use Toys::Definition#source_info and call find_data.
* ADDED: Context directory is kept in SourceInfo and available in the DSL and the tool runtime.
* IMPROVED: Optionally omit hidden subtools (i.e. names beginning with underscore)
  from subtool lists.
* IMPROVED: Optionally omit non-runnable namespaces from recursive subtool lists.

### v0.5.0 / 2018-10-07

* FIXED: Template instantiation was failing if the hosting tool was priority-masked.
* ADDED: Several additional characters can optionally be used as tool path delimiters.
* ADDED: Support for preloaded files and directories
* ADDED: Support for data directories
* ADDED: Ability to display just the list of subtools of a tool
* IMPROVED: The tool directive can now take an array as the tool name.
* IMPROVED: The tool directive can now take an `if_defined` argument.

### v0.4.5 / 2018-08-05

* CHANGED: Dropped preload file feature

### v0.4.4 / 2018-07-21

* FIXED: Utils::Exec wasn't closing streams after copying.
* IMPROVED: Utils::Exec::Controller can capture or redirect the remainder of a controlled stream.
* ADDED: Terminal#ask

### v0.4.3 / 2018-07-13

* IMPROVED: Utils::Exec methods can now spawn subprocesses in the background
* IMPROVED: Utils::Exec capture methods can now yield a controller

### v0.4.2 / 2018-07-08

* FIXED: Raise an error rather than cause unexpected behavior if a mixin is included twice.
* IMPROVED: The `include?` method extended to support mixin names in a tool dsl.

### v0.4.1 / 2018-07-03

* FIXED: Terminal#confirm uppercased "N" for the wrong default.

### v0.4.0 / 2018-07-03

Now declaring this alpha quality. Backward-incompatible changes are still
possible from this point, but I'll try to avoid them.

* CHANGED: Utils::Terminal#confirm default is now unset by default
* CHANGED: Moved gem install/activation methods into a mixin
* IMPROVED: Toys::Utils::Gems can suppress the confirmation prompt
* IMPROVED: Magic comments are now honored in toys files.
* IMPROVED: Utils::Gems installation is now much faster.
* FIXED: Utils::Gems didn't reset the specifications on Ruby 2.3.

### v0.3.11 / 2018-07-02

* CHANGED: Require Ruby 2.3 or later
* CHANGED: Renamed "set" directive to "static" to reduce confusion with Tool#set.
* ADDED: Convenience methods for getting option values

### v0.3.10 / 2018-06-30

* CHANGED: Dropped Tool#option. Use Tool#get instead.
* CHANGED: "run" directive renamed to "to_run"
* CHANGED: Highline mixin now uses Highline 2.0
* CHANGED: Middleware-added keys no longer show up in the options hash
* ADDED: Mixins can provide initializers
* ADDED: Loader can load an inline block

### v0.3.9.1 / 2018-06-24

* FIXED: Built-in flags were interfering with disable_argument_parsing

### v0.3.9 / 2018-06-24

* CHANGED: Cli#add_search_path_hierarchy changed the behavior of the base/terminate param
* CHANGED: Removed alias_as directive since it's incompatible with selective loading.
* ADDED: Ability to define named templates in Toys files
* ADDED: Ability to disable argument parsing
* ADDED: Exec#exec_proc and Exec#exec_tool that supports all the stream redirects
* IMPROVED: Acceptors can be looked up recursively in the same way as mixins and templates

### v0.3.8 / 2018-06-10

* CHANGED: Renamed helpers to mixins.
* CHANGED: ModuleLookup is now a customizable class and can have multiple sources.
* CHANGED: Moved the existing templates to the toys gem since they are rake replacements.
* CHANGED: Renamed :in_from, :out_to, and :err_to exec options to :in, :out, :err
* ADDED: CLI can now customize the standard mixins, templates, and middleware.
* IMPROVED: Exec raises an error if passed an unknown option.
* IMPROVED: Exec now accepts nearly all the same stream specifications as Process#spawn.

### v0.3.7.1 / 2018-05-30

* No changes.

### v0.3.7 / 2018-05-30

* CHANGED: Execution runs in the same scope as the DSL, which lets us use normal methods instead of helper-blocks.
* CHANGED: Renamed "script" to "run", and allow setting of runnable by defining a "run" method
* CHANGED: Set up a constant scope for each config file, to make constant lookup make sense.
* CHANGED: Removed run_toys and dropped EXIT_ON_NONZERO_STATUS key in favor of using cli directly.
* CHANGED: Renamed definition_path to source_path
* CHANGED: LineOutput util changed to a simple Terminal util, and folded spinner into it.
* CHANGED: Removed spinner helper and added terminal helper.
* CHANGED: Organized DSL and definition classes
* ADDED: Helper modules scoped to the tool hierarchy
* ADDED: Utility that installs and activates third-party gems.

### v0.3.6 / 2018-05-21

* CHANGED: Renamed show_version middleware to show_root_version.
* CHANGED: Reworked set_default_descriptions interface for more flexibility.
* CHANGED: Renamed Utils::Exec#config_defaults to configure_defaults to match the helper.
* CHANGED: Removed Context#new_cli and exposed Context#cli instead.
* CHANGED: Renamed CLI#empty_clone to CLI#child.
* IMPROVED: show_help middleware lets you control display of the source path section.
* IMPROVED: Optional parameters are now supported for flags.
* IMPROVED: Support custom acceptors.
* IMPROVED: Highline helper automatically sets use_color based on the type of stdout.

### v0.3.5 / 2018-05-15

* CHANGED: Exec logic now lives in a utils class.
* CHANGED: Moved flag and arg blocks from Tool into the DSL.
* CHANGED: Renamed `execute do` to `script do`, and Tool#executor to Tool#script.
* IMPROVED: Help display can use `less` if available.

### v0.3.4 / 2018-05-14

* CHANGED: Renamed switch to flag
* CHANGED: Renamed Utils::Usage to Utils::HelpText
* CHANGED: Renamed show_usage middleware to show_help and default everything false.
* CHANGED: Renamed docs: parameter again, to desc: and long_desc: to match tool desc.
* CHANGED: Middleware config method takes a loader as the second arg
* CHANGED: desc is now a single string rather than an array.
* CHANGED: Removed Loader#execute, and returned remaining args from Loader#lookup.
* CHANGED: Wrapped most errors with Toys::ContextualError
* CHANGED: accept: parameter now controls whether a switch takes a value by default
* CHANGED: Explicit and implicit show-help now handled by separate middleware instances
* CHANGED: All description strings are now wrappable
* IMPROVED: gem_build template can suppress interactive confirmation.
* IMPROVED: Logger colors the header when possible.
* IMPROVED: HelpText class can now generate nicer help pages
* IMPROVED: Style support for spinner helper
* IMPROVED: Set default descriptions for flags and args
* ADDED: CLI now takes an error handler to report most errors.
* ADDED: Alias DSL methods `required`, `optional`, and `remaining`.
* FIXED: Finish definitions for subtools since the desc may depend on it

### v0.3.3 / 2018-05-09

* CHANGED: Renamed file_utils helper to fileutils.
* CHANGED: Renamed `doc:` parameter to `docs:`.
* CHANGED: SwitchDefinition has separate fields for acceptor and docs.
* CHANGED: Description and long description are now arrays of strings.
* FIXED: Documentation strings that begin with "--" no longer cause problems.
* ADDED: Highline helper
* ADDED: Spinner helper
* ADDED: WrappableString for descriptions and docs
* IMPROVED: Usage can now customize the left column width and indent
* IMPROVED: Newlines in documentation are properly indented

### v0.3.2 / 2018-05-07

* CHANGED: Split core engine out into "toys-core" from the "toys" gem.
* CHANGED: Renamed path types to "search" and "config" paths, and restricted the former to the CLI.
* CHANGED: Removed aliasing from the Tool interface and reimplemented in the Loader.
* CHANGED: Default descriptions are now set via a middleware rather than in the Tool.
* CHANGED: Renamed most of the middleware classes.
* CHANGED: Combined usage-displaying middleware.
* CHANGED: Standard paths logic moved from CLI to StandardCLI.
* ADDED: Middleware that responds to the "--version" switch.
* ADDED: Context#new_cli that lets you run sub-instances of toys.
* IMPROVED: Middleware can now be referenced by class and constructed implicitly.
* IMPROVED: Usage error handler can now have its exit code configured.
* IMPROVED: Help and verbosity middlewares can have their switches configured.
* IMPROVED: Help middleware can search for keywords in subcommands.
* IMPROVED: Help middleware displays the config path in verbose mode.
* IMPROVED: Context::EXIT_ON_NONZERO_STATUS controls Context#run behavior.
* DOCS: Expanded middleware documentation
* INTERNAL: Removed Context::Base and just used CLI as base context
