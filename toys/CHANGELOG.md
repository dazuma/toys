# Release History

### 0.3.2 / TBD

* CHANGED: Split core engine out into separate "toys-core" gem. See the
  toys-core changelog for additional changes in core.
* ADDED: The root tool now responds to the "--version" switch.
* ADDED: Group help can now "--search" for subcommands.
* ADDED: You can now run a sub-instance of toys from an executor.

### 0.3.1 / 2018-05-02

* CHANGED: Subcommand display is now recursive by default.
* IMPROVED: Improved error messaging for bad switch syntax.
* FIXED: toys system update now reports experimental versions correctly.
* FIXED: Subtools of an overridden group are now properly deleted.
* DOCS: Completed a first pass on class and method documentation.
* INTERNAL: Adjusted naming of switch-related methods.

### 0.3.0 / 2018-04-30

* Initial generally usable release
