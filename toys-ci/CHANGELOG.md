# Release History

### v0.2.0 / 2026-05-05

* BREAKING CHANGE: Template classes no longer automatically include `Toys::Context::Key`. This behavior was undocumented and inconsistent between different ways of defining templates.
* ADDED: The `:gems` mixin provides a context key for retrieving the underlying `Toys::Utils::Gems` service object
* ADDED: The `:gems` mixin provides an explicit `Toys::Utils::Gems::ClassMethods` module defining the directives added to the tool class
* ADDED: The `activate` and `bundle` methods in the Gems utility now return useful results
* FIXED: Template classes no longer automatically include `Toys::Context::Key`. This behavior was undocumented and inconsistent between different ways of defining templates.
* DOCS: Updates to readme and user guide documentation
* DOCS: Various documentation updates

### v0.1.0 / 2026-03-11

* Initial release
