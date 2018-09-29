# Release History

### 0.5.0 / TBD

* ADDED: Several additional characters can optionally be used as tool path delimiters.

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
