# Release History

### master

### 0.10.2 / 2020-07-03

* FIXED: The load path no longer loses the toys and toys-core directories after a bundle install.

### 0.10.1 / 2020-03-07

* FIXED: Setting `:exit_on_nonzero_status` explicitly to false now works as expected.

### 0.10.0 / 2020-02-24

* ADDED: `:bundler` mixin that installs and sets up a bundle for the tool
* ADDED: `bundler` options in the standard templates, to run those tools in a bundle
* ADDED: `subtool_apply` directive which applies a block to all subtools.
* ADDED: Add `.lib` directories to the Ruby load path when executing a tool.
* ADDED: `toys_version?` and `toys_version!` directives that check against version requirements.
* ADDED: `exec_separate_tool` and `capture_separate_tool` methods in the `:exec` mixin, to support executing tools in a separate process without forking
* IMPROVED: `long_desc` directive can now read the description from a text file.
* IMPROVED: The `tool` directive can take delimited strings as tool names.
* IMPROVED: Subtool blocks aren't actually executed unless the tool is needed.
* CHANGED: Added `on_missing` and `on_conflict` arguments to `Toys::Utils::Gems` constructor (which also affects the `:gems` mixin), and deprecated `suppress_confirm` and `default_confirm`.
* CHANGED: Tightened `rdoc` template's default gem version to `~> 6.1.0`.
* FIXED: `rdoc` template crashed if any nonstandard options were given.
* FIXED: `rubocop` template would abort prematurely if standard streams were redirected.

### 0.9.4 / 2020-01-26

* FIXED: Crash in the loader when a non-ruby file appears in a toys directory

### 0.9.3 / 2020-01-05

* FIXED: `delegate_to` directive could crash if an overriding tool has already been defined.
* FIXED: A Ruby 2.7 warning when reporting a Toys file syntax error.

### 0.9.2 / 2020-01-03

* IMPROVED: Mixins can now take real keyword arguments, and will pass them on properly to `on_initialize` and `on_include` blocks.
* CHANGED: `Toys::Utils::Exec` and the `:exec` mixin methods now take real keyword arguments rather than an `opts` hash. This means you should use keywords (or the double-splat operator) to avoid a deprecation warning on Ruby 2.7.

### 0.9.1 / 2019-12-22

* IMPROVED: `delegate_to` and `alias_tool` can take symbols as well as strings.
* DOCS: Fixed user guide internal links on rubydoc.info.

### 0.9.0 / 2019-12-02

* ADDED: The `delegate_to` directive causes the tool to delegate execution to another tool. This means it takes the same arguments and has the same execution behavior.
* ADDED: The `delegate_to` argument to the `tool` directive causes the tool to delegate to another tool. (Note: the `alias_tool` directive is now just shorthand for creating a tool with a delegate, and as such is mildly deprecated.)
* ADDED: The `current_tool` function can be called from the DSL to get the current `Toys::Tool` object.
* ADDED: The `:e` option is now an alias for `:exit_on_nonzero_status`.
* IMPROVED: `alias_tool` is now just shorthand for delegating. This means, aliases can now point to namespaces and will resolve subtools of their targets, and they now support tab completion and online help.
* IMPROVED: This release of Toys is now compatible with Ruby 2.7.0-preview3. It fixes some Ruby 2.7 specific bugs, and sanitizes keyword argument usage to eliminate Ruby 2.7 warnings.
* IMPROVED: JRuby is now supported for most operations. However, JRuby is generally not recommended because of JVM boot latency, lack of Kernel#fork support, and other issues.
* FIXED: The the `tool` directive no longer crashes if not passed a block.

### 0.8.1 / 2019-11-19

* FIXED: Listing subtools would crash if a broken alias was present.
* DOCUMENTATION: Switched from redcarpet to kramdown, and tried to make some structural fixes.

### 0.8.0 / 2019-06-20

This is a major update with significant new features and a bunch of fixes.
It does include a few minor backward-incompatible changes. All signifiant
features planned for beta are now implemented.

Highlights:

* Tab completion is available for Bash! See the README for instructions on installing it. Tab completion covers tool names, flags, flag values, and positional arguments. Tools can also customize the completion for their own flag and argument values.
* Toys now integrates with `did_you_mean` to provide suggestions for misspelled tools, flags, and arguments (when run on Ruby 2.4 or later.)
* Tools can now provide their own interrupt handler to respond to user `CTRL-C`. And the default handler no longer displays an unsightly stack trace. Tools can also provide their own handler for usage errors.
* A new argument parsing engine, supporting additional features such as optional enforcing that flags appear before positional arguments, as well as a bunch of fixes, especially around acceptors and optional flag values.
* Changed the license from BSD to MIT to better match how most libraries in the Ruby community are licensed.

Details:

* CHANGED: Relicensed under the MIT License.
* CHANGED: Requires Ruby 2.3 or later.
* ADDED: Tab completion for bash. Args and flags can provide their own completion information.
* ADDED: The usage error screen displays alternative suggestions when an argument is misspelled. (Requires Ruby 2.4 or later.)
* ADDED: Tools can provide an interrupt handler.
* ADDED: Tools can enforce that flags must be given before positional args. In particular, `toys do` now uses this feature, which eliminates most of the need to use `--` to get flags to work for subtools.
* ADDED: Tools can control whether their flags can be invoked by partial matches.
* ADDED: Function and range based acceptors.
* ADDED: Flag handlers can accept the symbolic names `:set` and `:push` for common cases.
* ADDED: The `:gem_build` template includes an `:install_gem` option. It also allows customization of gem output path.
* ADDED: The `acceptor` directive takes an optional `type_desc` argument.
* ADDED: The `accept` directives under flag and positional arg blocks in the DSL can now take blocks and `type_desc` values.
* ADDED: Context keys `UNMATCHED_ARGS`, `UNMATCHED_POSITIONAL`, and `UNMATCHED_FLAGS` that provide arguments that were not handled during arg parsing.
* ADDED: The Exec util and mixin support specifying a callback for process results.
* ADDED: The Exec util and mixin provide a way to identify processes by name.
* CHANGED: Toys now implements its own argument parsing and standard acceptors rather than relying on OptionParser. For the most part, OptionParser behavior is preserved, except in cases where there is clearly a bug.
* CHANGED: Flags create a short form flag by default if the name has one character.
* CHANGED: Flags with explicit value-less syntax are no longer given a value even if they specify a default or an acceptor.
* CHANGED: Renamed the `TOOL_DEFINITION` context key to `TOOL`, and removed the `tool_definition` convenience method.
* CHANGED: Removed the `BINARY_NAME` and `LOADER` context keys, and removed and the corresponding convenience methods. Get these values from the CLI if needed.
* CHANGED: Renamed the `USAGE_ERROR` context key to `USAGE_ERRORS`, and the corresponding convenience method to `usage_errors`. The value is now a (possibly empty) array of `Toys::ArgParser::UsageError` objects rather than a string that isn't machine-parseable.
* CHANGED: The root tool no longer defines remaining_args.
* CHANGED: Renamed `to_expand` to `on_expand` in template definitions.
* CHANGED: Renamed `to_initialize` to `on_initialize`, and `to_include` to `on_include` in mixin definitions.
* CHANGED: Default descriptions for flag groups is now handled by the `set_default_descriptions` middleware rather than hard-coded in FlagGroup.
* CHANGED: Exec reports failure to start processes in the result object rather than, e.g. raising ENOENT.
* IMPROVED: Toys no longer displays a stack trace if a tool is interrupted.
* IMPROVED: Error messages for flag groups are more complete.
* IMPROVED: All context data, including well-known data, is available to be modified by flags and args.
* FIXED: Flags with optional values are properly set to `true` (rather than left at `nil`) if no value is provided.
* FIXED: Prevented toys-core from being ousted from the load path if a toys file invoked bundler setup.
* FIXED: Acceptors no longer raise errors when run on missing optional values.
* FIXED: When reporting errors in toys files, the line number was off by 2.
* FIXED: The `--usage` help flag now honors `--all` and `--no-recursive`.
* FIXED: The terminal now handles nil streams, as advertised.

Additionally, a significant amount of internal reorganization and cleanup happened in the toys-core gem. See the changelog for toys-core for more details.

### 0.7.0 / 2019-01-23

* ADDED: A template for creating tools that invoke RSpec.
* ADDED: Flag groups, which enforce policies around which flags are required.
* CHANGED: Flags within a group are sorted in the help screens.
* IMPROVED: The minitest template now honors all standard minitest flags.

### 0.6.1 / 2019-01-07

* FIXED: The presence of aliases caused subtool listing to crash.

### 0.6.0 / 2018-10-22

* FIXED: Build tools cd into the context directory when running.
* FIXED: Rakefiles are evaluated and tasks are run in the Rakefile's directory.
* ADDED: Context directory is available in the DSL and the tool runtime.
* IMPROVED: Rake template searches parent directories for Rakefile.
* IMPROVED: Rake tasks show the Rakefile path in the long description.
* IMPROVED: Subtools whose names begin with underscore are no longer listed in help
  screens unless the `--all` flag is given.
* IMPROVED: Non-runnable namespaces are no longer displayed in recursive subtool
  lists if their children are already displayed.

### 0.5.0 / 2018-10-07

* ADDED: Period and colon are recognized as tool path delimiters.
* ADDED: New rake template that supports loading rake tasks as tools.
* ADDED: Files named ".preload.rb" and files in a ".preload" directory are loaded before tools are defined.
* ADDED: Directories named ".data" can contain data files accessible from tools.
* ADDED: Passing "--tools" displays just the list of subtools of a tool
* IMPROVED: The tool directive can now take an array as the tool name.
* IMPROVED: The tool directive can now take an `if_defined` argument.
* FIXED: Template instantiation was failing if the hosting tool was priority-masked.

### 0.4.5 / 2018-08-05

* CHANGED: Dropped preload file feature

### 0.4.4 / 2018-07-21

* FIXED: Utils::Exec wasn't closing streams after copying.
* IMPROVED: Utils::Exec::Controller can capture or redirect the remainder of a controlled stream.
* ADDED: Terminal#ask

### 0.4.3 / 2018-07-13

* IMPROVED: Exec mixin methods can now spawn subprocesses in the background
* IMPROVED: Exec mixin capture methods can now yield a controller

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

### 0.3.11 / 2018-07-02

* CHANGED: Require Ruby 2.3 or later
* CHANGED: Renamed "set" directive to "static" to reduce confusion with Tool#set.
* ADDED: Convenience methods for getting option values

### 0.3.10 / 2018-06-30

* CHANGED: Dropped Tool#option. Use Tool#get instead.
* CHANGED: "run" directive renamed to "to_run"
* CHANGED: Highline mixin now uses Highline 2.0
* ADDED: Mixins can provide initializers

### 0.3.9.1 / 2018-06-24

* FIXED: Built-in flags were interfering with disable_argument_parsing

### 0.3.9 / 2018-06-24

* CHANGED: Removed alias_as directive since it's incompatible with selective loading.
* ADDED: Ability to define named templates in Toys files
* ADDED: Ability to disable argument parsing
* ADDED: Rdoc template
* ADDED: Exec#exec_proc and Exec#exec_tool that supports all the stream redirects
* IMPROVED: Acceptors can be looked up recursively in the same way as mixins and templates
* FIXED: Templates were not activating needed gems

### 0.3.8 / 2018-06-10

* CHANGED: Renamed helpers to mixins.
* CHANGED: Renamed :in_from, :out_to, and :err_to exec options to :in, :out, :err
* IMPROVED: Exec raises an error if passed an unknown option.
* IMPROVED: Exec now accepts nearly all the same stream specifications as Process#spawn.

### 0.3.7.1 / 2018-05-30

* FIXED: Fix crash in system update.

### 0.3.7 / 2018-05-30

* CHANGED: Execution runs in the same scope as the DSL, which lets us use normal methods instead of helper-blocks.
* CHANGED: Renamed "script" to "run", and allow setting of runnable by defining a "run" method
* CHANGED: Set up a constant scope for each config file, to make constant lookup make sense.
* CHANGED: Removed run_toys and dropped EXIT_ON_NONZERO_STATUS key in favor of using cli directly.
* CHANGED: Removed spinner helper and added terminal helper.
* ADDED: Helper modules scoped to the tool hierarchy

### 0.3.6 / 2018-05-21

* CHANGED: Removed Context#new_cli and exposed Context#cli instead.
* CHANGED: Raises ToolDefinitionError if you declare a duplicate flag.
* IMPROVED: Provide more details in default descriptions.
* IMPROVED: Optional parameters are now supported for flags.
* IMPROVED: Support custom acceptors.
* IMPROVED: Highline helper automatically sets use_color based on the type of stdout.

### 0.3.5 / 2018-05-15

* CHANGED: Flag and arg blocks in the DSL have an interface more similar to the rest of the DSL.
* CHANGED: Renamed `execute do` to `script do`.
* IMPROVED: Help display uses `less` if available.

### 0.3.4 / 2018-05-14

* CHANGED: Renamed switch to flag
* CHANGED: Renamed docs: parameter again, to desc: and long_desc: to match tool desc.
* CHANGED: desc is now a single string rather than an array.
* CHANGED: accept: parameter now controls whether a switch takes a value by default
* IMPROVED: Nicer help page format
* IMPROVED: gem_build template can suppress interactive confirmation.
* IMPROVED: system update builtin can optionally ask for confirmation.
* IMPROVED: Error reporting is significantly improved.
* IMPROVED: Logger colors the header when possible.
* IMPROVED: Style support for spinner helper
* IMPROVED: Set default descriptions for flags and args
* ADDED: Alias DSL methods `required`, `optional`, and `remaining`.
* FIXED: Subtools with no desc now properly pick up the default
* FIXED: Usage errors and show-help now interact in the right way

### 0.3.3 / 2018-05-09

* CHANGED: Renamed file_utils helper to fileutils.
* CHANGED: Renamed doc: parameter to docs:
* FIXED: Documentation strings that begin with "-" no longer cause problems.
* ADDED: Highline helper
* ADDED: Spinner helper
* ADDED: WrappableString for descriptions and docs
* IMPROVED: Descriptions can have multiple lines

### 0.3.2 / 2018-05-07

* CHANGED: Split core engine out into separate "toys-core" gem. See the
  toys-core changelog for additional changes in core.
* CHANGED: Tools can no longer be alias_of. However, alias_as still works, and
  it is now possible to create an alias using alias_tool.
* IMPROVED: The root tool now responds to the "--version" switch.
* IMPROVED: Group help can now "--search" for subcommands.
* IMPROVED: Help shows the config file path on "--verbose".
* IMPROVED: You can now run a sub-instance of toys from an executor.

### 0.3.1 / 2018-05-02

* CHANGED: Subcommand display is now recursive by default.
* IMPROVED: Improved error messaging for bad switch syntax.
* FIXED: toys system update now reports experimental versions correctly.
* FIXED: Subtools of an overridden group are now properly deleted.
* DOCS: Completed a first pass on class and method documentation.
* INTERNAL: Adjusted naming of switch-related methods.

### 0.3.0 / 2018-04-30

* Initial generally usable release
