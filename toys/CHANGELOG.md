# Release History

### 0.3.8 / TBD

* CHANGED: Renamed :in_from, :out_to, and :err_to exec options to :in, :out, :err

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
