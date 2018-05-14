# Release History

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
