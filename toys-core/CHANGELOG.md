# Release History

### 0.8.0 / Unreleased

This is a major update with significant new features and a bunch of fixes. It also includes a significant amount of internal reorganization and cleanup, some of which resulted in backward incompatible changes. Basic use should not be affected. All features planned for beta are now implemented.

Major changes and features:

* CHANGED: Relicensed under the MIT License.
* ADDED: Tab completion for bash. Added APIs and DSL constructs for tools to customize completions.
* ADDED: The usage error screen displays suggestions when an argument is misspelled. (Requires Ruby 2.4 or later.)
* ADDED: Tools can provide an interrupt handler and a custom usage error handler. Added appropriate APIs and DSL methods.
* ADDED: Tools can enforce that flags must be given before positional args.

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

### 0.7.0 / 2019-01-23

* ADDED: Flag groups, which enforce policies around which flags are required.
* CHANGED: Flags within a group are sorted in help screens.
* CHANGED: Canonical flag within a flag definition is now the first rather than the last.

### 0.6.1 / 2019-01-07

* FIXED: The presence of aliases caused subtool listing to crash.

### 0.6.0 / 2018-10-22

* CHANGED: Replaced Toys::Definition::DataFinder with Toys::Definition::SourceInfo.
* CHANGED: Removed Toys::Definition#find_data. Use Toys::Definition#source_info and call find_data.
* ADDED: Context directory is kept in SourceInfo and available in the DSL and the tool runtime.
* IMPROVED: Optionally omit hidden subtools (i.e. names beginning with underscore)
  from subtool lists.
* IMPROVED: Optionally omit non-runnable namespaces from recursive subtool lists.

### 0.5.0 / 2018-10-07

* FIXED: Template instantiation was failing if the hosting tool was priority-masked.
* ADDED: Several additional characters can optionally be used as tool path delimiters.
* ADDED: Support for preloaded files and directories
* ADDED: Support for data directories
* ADDED: Ability to display just the list of subtools of a tool
* IMPROVED: The tool directive can now take an array as the tool name.
* IMPROVED: The tool directive can now take an `if_defined` argument.

### 0.4.5 / 2018-08-05

* CHANGED: Dropped preload file feature

### 0.4.4 / 2018-07-21

* FIXED: Utils::Exec wasn't closing streams after copying.
* IMPROVED: Utils::Exec::Controller can capture or redirect the remainder of a controlled stream.
* ADDED: Terminal#ask

### 0.4.3 / 2018-07-13

* IMPROVED: Utils::Exec methods can now spawn subprocesses in the background
* IMPROVED: Utils::Exec capture methods can now yield a controller

### 0.4.2 / 2018-07-08

* FIXED: Raise an error rather than cause unexpected behavior if a mixin is included twice.
* IMPROVED: The `include?` method extended to support mixin names in a tool dsl.

### 0.4.1 / 2018-07-03

* FIXED: Terminal#confirm uppercased "N" for the wrong default.

### 0.4.0 / 2018-07-03

Now declaring this alpha quality. Backward-incompatible changes are still
possible from this point, but I'll try to avoid them.

* CHANGED: Utils::Terminal#confirm default is now unset by default
* CHANGED: Moved gem install/activation methods into a mixin
* IMPROVED: Toys::Utils::Gems can suppress the confirmation prompt
* IMPROVED: Magic comments are now honored in toys files.
* IMPROVED: Utils::Gems installation is now much faster.
* FIXED: Utils::Gems didn't reset the specifications on Ruby 2.3.

### 0.3.11 / 2018-07-02

* CHANGED: Require Ruby 2.3 or later
* CHANGED: Renamed "set" directive to "static" to reduce confusion with Tool#set.
* ADDED: Convenience methods for getting option values

### 0.3.10 / 2018-06-30

* CHANGED: Dropped Tool#option. Use Tool#get instead.
* CHANGED: "run" directive renamed to "to_run"
* CHANGED: Highline mixin now uses Highline 2.0
* CHANGED: Middleware-added keys no longer show up in the options hash
* ADDED: Mixins can provide initializers
* ADDED: Loader can load an inline block

### 0.3.9.1 / 2018-06-24

* FIXED: Built-in flags were interfering with disable_argument_parsing

### 0.3.9 / 2018-06-24

* CHANGED: Cli#add_search_path_hierarchy changed the behavior of the base/terminate param
* CHANGED: Removed alias_as directive since it's incompatible with selective loading.
* ADDED: Ability to define named templates in Toys files
* ADDED: Ability to disable argument parsing
* ADDED: Exec#exec_proc and Exec#exec_tool that supports all the stream redirects
* IMPROVED: Acceptors can be looked up recursively in the same way as mixins and templates

### 0.3.8 / 2018-06-10

* CHANGED: Renamed helpers to mixins.
* CHANGED: ModuleLookup is now a customizable class and can have multiple sources.
* CHANGED: Moved the existing templates to the toys gem since they are rake replacements.
* CHANGED: Renamed :in_from, :out_to, and :err_to exec options to :in, :out, :err
* ADDED: CLI can now customize the standard mixins, templates, and middleware.
* IMPROVED: Exec raises an error if passed an unknown option.
* IMPROVED: Exec now accepts nearly all the same stream specifications as Process#spawn.

### 0.3.7.1 / 2018-05-30

* No changes.

### 0.3.7 / 2018-05-30

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

### 0.3.6 / 2018-05-21

* CHANGED: Renamed show_version middleware to show_root_version.
* CHANGED: Reworked set_default_descriptions interface for more flexibility.
* CHANGED: Renamed Utils::Exec#config_defaults to configure_defaults to match the helper.
* CHANGED: Removed Context#new_cli and exposed Context#cli instead.
* CHANGED: Renamed CLI#empty_clone to CLI#child.
* IMPROVED: show_help middleware lets you control display of the source path section.
* IMPROVED: Optional parameters are now supported for flags.
* IMPROVED: Support custom acceptors.
* IMPROVED: Highline helper automatically sets use_color based on the type of stdout.

### 0.3.5 / 2018-05-15

* CHANGED: Exec logic now lives in a utils class.
* CHANGED: Moved flag and arg blocks from Tool into the DSL.
* CHANGED: Renamed `execute do` to `script do`, and Tool#executor to Tool#script.
* IMPROVED: Help display can use `less` if available.

### 0.3.4 / 2018-05-14

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

### 0.3.3 / 2018-05-09

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

### 0.3.2 / 2018-05-07

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
