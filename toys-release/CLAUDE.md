# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

toys-release is a Ruby library release automation system using GitHub Actions and Toys. It interprets conventional commit messages to automate changelog generation and version bumping based on semantic versioning, and uses GitHub pull requests for release approval. It can tag GitHub releases, push gems to RubyGems, and publish documentation to gh-pages. It depends on `toys-core ~> 0.17`.

## Development Commands

From the **repository root**, use the self-hosted `./toys-dev` bootstrap script:

```bash
./toys-dev test --only --release         # Run toys-release tests (via root test tool)
./toys-dev rubocop --only --release      # Run RuboCop (via root rubocop tool -- note flag is :release not :toys_release)
./toys-dev ci --only --test-release      # Run tests via CI runner
./toys-dev ci --only --rubocop-release   # Run RuboCop via CI runner
```

From **within the toys-release directory**:

```bash
../toys-dev test                         # Run tests
../toys-dev rubocop                      # Run RuboCop
../toys-dev yardoc                       # Generate YARD docs
../toys-dev build                        # Build the gem
```

Tests run via the built-in `system test` tool pointing at the `toys/` directory, which discovers tests in `toys/.test/`.

## Project Layout

This gem has an unusual layout compared to typical Ruby gems. The library code is split across two locations:

- **`lib/`** - Only contains `toys/release/version.rb` (the gem version constant). This is the gem's `require_paths` entry.
- **`toys/`** - Contains all the Toys tool definitions and the actual library code:
  - **`toys/.lib/toys/release/`** - The main library classes (loaded via Toys' `.lib` directory convention, not via `require_paths`)
  - **`toys/.test/`** - All tests and test fixtures
  - **`toys/.data/templates/`** - ERB templates for GitHub Actions workflows and gh-pages
  - Tool files at `toys/*.rb` - The release tools themselves

This layout means the library classes are loaded by Toys' `.lib` auto-load mechanism rather than standard `require`. Tests manually add `toys/.lib` to `$LOAD_PATH` in their helper.

## Architecture

### Release Tools (`toys/*.rb`)

These are the user-facing Toys tools:

- **`request.rb`** - Opens release pull requests. Analyzes commits since last release, updates version and changelog, pushes a release branch, and opens a PR.
- **`perform.rb`** - Executes a release by running the configured pipeline of steps.
- **`retry.rb`** - Retries a failed release.
- **`gen-workflows.rb`** - Generates GitHub Actions workflow YAML files from ERB templates.
- **`gen-config.rb`** - Generates a starter `releases.yml` configuration file.
- **`gen-gh-pages.rb`** - Sets up a gh-pages branch for documentation hosting.
- **`create-labels.rb`** - Creates GitHub labels for release PRs.
- **`_onpush.rb`** / **`_onclosed.rb`** - Webhook handlers for GitHub Actions (triggered on push and PR close events).

### Core Classes (`toys/.lib/toys/release/`)

- **`RepoSettings`** (~34KB) - Parses and validates the `releases.yml` configuration file. Defines `ComponentSettings`, `CommitTagSettings`, and `StepSettings` for configuring commit tags, semver behavior, changelog headers, and build pipeline steps.
- **`Repository`** - Represents the Git repository. Manages components, coordination groups, commits, branches, and interacts with `git` and `gh` CLI tools.
- **`Component`** - A releasable component (gem). Holds references to its changelog file, version.rb file, and change set. Supports coordination groups for multi-gem releases.
- **`ChangeSet`** - Collects and organizes commit messages into changelog groups. Computes the semver bump type (major/minor/patch) from conventional commit messages.
- **`Pipeline`** - Executes a sequence of release steps. Provides `StepContext` to each step with access to the repository and component being released.
- **`Performer`** - Orchestrates the release execution. Runs the pipeline for each component, collects results, and reports success/failure.
- **`Steps`** - Namespace for pipeline step implementations. Built-in steps include `NOOP`, `TOOL` (runs a Toys tool), `GEM_BUILD`, `GEM_PUSH`, `GITHUB_RELEASE`, `PUBLISH_DOCS`, etc. Steps implement `primary?`, `dependencies`, and `run` methods.
- **`RequestLogic`** - Logic for creating release PRs: verifies component state, creates release branches, edits changelogs and version files, and opens PRs via `gh`.
- **`RequestSpec`** - Specifies which components to release and at what versions.
- **`ChangelogFile`** / **`VersionRbFile`** - Read and modify `CHANGELOG.md` and `version.rb` files.
- **`CommitInfo`** - Parsed commit data (SHA, message).
- **`PullRequest`** - Represents a GitHub pull request.
- **`EnvironmentUtils`** - Utilities for running release scripts (logging, error accumulation, GitHub Actions integration, `git`/`gh` execution).
- **`Semver`** - Semantic version bump type constants (`NONE`, `PATCH`, `MINOR`, `MAJOR`).
- **`ArtifactDir`** - Manages temporary artifact directories during release.

### Configuration

Repositories configure releases via a `releases.yml` file (parsed by `RepoSettings`) that defines:
- Components (gems) and their paths, version files, changelog files
- Conventional commit tag mappings to semver types and changelog headers
- Coordination groups for multi-gem synchronized releases
- Pipeline steps for the build/release process

### Templates (`toys/.data/templates/`)

ERB templates for generating GitHub Actions workflow files (`release-*.yml.erb`) and gh-pages scaffolding.

## Testing

- Tests live in `toys/.test/` using Minitest spec style with assertions
- Test helper (`toys/.test/helper.rb`) manually adds `toys/.lib` to `$LOAD_PATH` and requires all library classes
- Test fixtures in `toys/.test/.data/` (changelog files, version files, directory structures)
- Tests use mock objects for `EnvironmentUtils` and `Repository` to avoid Git/GitHub interactions
- On GitHub CI, the test helper automatically unshallows the repo for commit history tests
