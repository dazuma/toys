# Release History

### v0.5.0 / 2026-01-27

* ADDED: Support for updating release pull requests when new commits are added
* ADDED: Multiple release pull requests are now allowed as long as they don't release any of the same components
* FIXED: Use v6 of the checkout action
* FIXED: Reverting a commit that itself does a revert does the right thing
* FIXED: Fixed error when requesting a release from a branch with a slash in the name
* FIXED: Update toys-release
* FIXED: Update toys-release 4

### v0.4.0 / 2026-01-06

* ADDED: Actions workflows use Ruby 4.0 and Toys 0.19 or later
* FIXED: Output formatting in setup utilities is more consistent

### v0.3.2 / 2025-12-25

* DOCS: Some formatting fixes in the user guide

### v0.3.1 / 2025-12-22

* FIXED: Reset the local repository prior to each pipeline step
* DOCS: Updates to readmes and users guides

### v0.3.0 / 2025-12-06

This release includes fairly substantial changes, a few of them breaking, to the configuration mechanism:
* Component types have been removed. You can customize the pipeline for specific components, but there are no longer any predefined "categories" of components.
* Commit tag handling can be overridden for specific components.
* Added a configuration to control how collisions during file copies (in inputs and outputs) are resolved.
* Unknown or misspelled keys in the configuration now trigger an error.

Aditional changes:
* Renamed the gen-settings tool to gen-config and expanded its capabilities, including generating git_user_name and git_user_email.
* When the release automation starts, it posts a comment on the release pull request with a link to its logs.
* Initial work on the users guide.

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
