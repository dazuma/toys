# Release History

### v0.18.1 / 2026-01-25

* FIXED: Significant change to common-tools

### v0.18.0 / 2025-11-30

* BREAKING CHANGE: Removed release tooling from common-tools; use the toys-release gem instead

### v0.17.1 / 2025-11-04

* FIXED: Toys release request covers all releasable components if no components are specified

### v0.17.0 / 2025-11-04

* ADDED: Support for include_globs and exclude_globs
* ADDED: Included the github logs link in release reports
* ADDED: Remove --enable-releases flag and use TOYS_RELEASE_DRY_RUN environment variable instead
* ADDED: Add more fine-grained permissions settings to release action workflows
* ADDED: Support for custom behavior for commit scopes
* ADDED: Support for modifying commit tag configuration
* FIXED: Ignore extra text on revert-commit and semver-change tags

### v0.16.2 / 2025-10-31

* FIXED: Fix crash in the additional change notification

### v0.16.1 / 2025-10-31

* FIXED: Release performer no longer reports spurious github check errors

### v0.16.0 / 2025-10-31

* ADDED: Included flexible CI system
* ADDED: New release script implementation
* ADDED: Release scripts support non-gem releasable units
* ADDED: Release scripts support more flexible coordination grouping
* ADDED: Release configuration supports more fine grained customization of build steps
* ADDED: Support for using a custom github token for release requests
* ADDED: Provided release tools to create gh-pages
* ADDED: Updated Ruby and action versions in GitHub Actions workflows

### v0.15.5.1 / 2024-02-07

* FIXED: Fixed crash when requesting release of a new gem
