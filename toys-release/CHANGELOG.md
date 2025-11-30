# Release History

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
