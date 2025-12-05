# Release History

### v0.3.0 / 2025-12-05

* BREAKING CHANGE: Remove component types to simplify configuration mechanism
* ADDED: Provided a gen-config tool
* ADDED: Support different options for handling collisions during file copies
* ADDED: Support for per-component overrides of commit tag behavior
* ADDED: Remove component types to simplify configuration mechanism
* ADDED: Check for unknown or misspelled keys when loading configuration
* ADDED: The gen-config tool now generates git_user_name and git_user_email fields
* DOCS: Initial work on the users guide

### v0.2.2 / 2025-11-30

* FIXED: Fixed several crashes in the retry tool
* FIXED: Fixed step cleaner trying to clean the .git directory on non-monorepos
* FIXED: Repo prechecks can now actually stop releases from being performed
* FIXED: Retry tool uses --work-dir= instead of --gh-pages-dir=
* FIXED: Dry run mode no longer attempts to update pull requests or open issues

### v0.2.1 / 2025-11-30

* FIXED: Fixed some typos in the release pipeline logs
* DOCS: Fixed minor typos in readme files

### v0.2.0 / 2025-11-30

* BREAKING CHANGE: Reworked pipeline design and normalized how steps communicate
* BREAKING CHANGE: Removed defunct commit linter

### v0.1.1 / 2025-11-09

* FIXED: The gen-gh-pages script now generates the correct redirect paths on a non-monorepo with the default directory structure
* FIXED: The gen-gh-pages script no longer exits abnormally if no changes were made

### v0.1.0 / 2025-11-09

Initial release of the toys-release gem
