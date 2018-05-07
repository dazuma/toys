# Release History

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
