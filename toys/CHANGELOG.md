# Release History

### 0.3.5 / TBD

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
