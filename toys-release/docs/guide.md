<!--
# @title Toys-Release User Guide
-->

# Toys-Release User Guide

Toys-Release is a release pipeline system built on GitHub Actions and the Toys
RubyGem. It interprets [conventional commit](https://conventionalcommits.org/)
message format to automate changelog generation and updates library versions
based on semantic versioning. It supports fine tuning and approval of releases
using GitHub pull requests.

Out of the box, Toys-Release knows how to tag GitHub releases, build and push
RubyGems packages, and build and publish documentation to gh-pages. You can
customize the build pipeline and many aspects of its behavior.

This user's guide covers all the features of Toys-Release in detail, including
installation, normal operations, release pipeline customization, and a full
configuration reference.

**(This user's guide is still under construction.)**

## Conceptual overview

Toys-Release is a comprehensive release pipeline system. It includes a set of
**command line tools** (built using the Toys framework) and a set of
**GitHub actions** that can be integrated into a GitHub repository to provide a
way to release new versions of packages present in that repository.

Toys-Release depends on the repository utilizing the **conventional commits**
standard (https://conventionalcommits.org) to describe the changes made in each
commit to the repository. Using this information, it automatically generates
**changelog** entries and chooses a new package version to release, according
to the **semantic versioning** standard (https://semver.org/).

Releases are requested explicitly by a repository maintainer by running a
command line tool or triggering a GitHub action. Toys-Release will configure
the release and open a **release pull request** describing the release. When
this pull request is merged, Toys-Release will automatically perform the
release. The pull request can also be modified to customize the release, or
closed without merging to cancel the release.

Toys-Release depends on a **configuration file** to describe which packages are
present in a repository and how to release them. It supports repositories
containing either a single package, or multiple packages (i.e. "**monorepos**")
and can analyze a repository to identify changes applying to each package.

Toys-Release can build **GitHub releases**, publish **RubyGems packages**, and
build and publish documentation to **GitHub pages**.

Toys-Release uses the [Toys](https://dazuma.github.io/toys/gems/toys/latest)
RubyGem, but does not require familiarity with Toys.

## Installation

Toys-Release must be installed into a GitHub repository. This involves:

* Installing a Toys tool;
* Writing a configuration file;
* Defining a set of GitHub Actions workflows and a set of GitHub labels
  (a tool is provided to perform this step); and
* Providing necessary credentials.

### Prerequisites

Toys-Release is written in Ruby, using the Toys framework. The installation
process requires these items to be installed locally, but normal operation
happens in GitHub Actions and does not require any local installation.

If you do not have Ruby or Toys installed locally, do so first. Install
Ruby 3.0 or later, and then install the Toys RubyGem using:

```sh
gem install toys
```

Toys-Release requires Toys 0.18 or later. If you have an older version of Toys,
update it using:

```sh
toys system update
```

Finally, you also need the GitHub command line tool, `gh`. Find installation
instructions at https://cli.github.com/. If you are running on MacOS, for
example, the easiest way to install it is via homebrew:

```sh
brew install gh
```

### Install the release tool

The Toys-Release tool needs to be installed in your repository, as a Toys tool
loaded from the [toys-release](https://rubygems.org/gems/toys-release) gem.

Create `.toys/release.rb` (note the leading period in the directory name) in
your git repository. Use the following content:

```ruby
load_gem "toys-release"
```

This will cause Toys-Release to use the latest version of Toys-Release. You can
also pin to a specific version of Toys-Release by specifying version
requirements similar to how those requirements are specified in RubyGems or
Bundler:

```ruby
load_gem "toys-release", "~> 0.3"
```

Commit and push this change to your repository.

### Write the configuration file

Next you will provide a configuration file for releases. This file is located
in your repository at `.toys/.data/releases.yml` (note the leading periods) and
lists all the releasable components (such as RubyGems packages) in your
repository, along with any customizations to the build/release process and
pipeline behavior.

To get you started, Toys-Release provides a config generation tool. Once the
release tool is installed as described above, you can run this from your local
repository clone directory:

```sh
toys release gen-config
```

This will analyze your repository and generate an initial configuration file
for you. It will make a guess as to what releasable components/RubyGems are
present in your repository. At this stage, you do not need to get every
configuration exactly correct, but feel free to begin editing it if you so
choose. The remaining sections in this user's guide will cover the release
capabilities that you may need to configure in this file, and the
[configuration reference](#configuration-reference) section below describes the
file format in detail.

### Install workflows and labels

Once an initial configuration file is present, you can finish the rest of the
installation by creating some needed labels in your GitHub repository and
installing some needed GitHub Actions workflows. These are done on the command
line using the release tool.

To create the GitHub repo labels, run this from your local repo clone directory:

```sh
toys release create-labels
```

Then, to generate the GitHub Actions workflows, run:

```sh
toys release gen-workflows
```

This will generate files in a `.github/workflows` directory in your repository.
Commit and push this change (along with the configuration file) to your
repository.

### Provide credentials

If Toys-Release will publish RubyGems packages, it will require credentials.
Provide those by creating a GitHub Actions Secret called `RUBYGEMS_API_KEY`.

In your GitHub repository web UI, go to the Settings tab, and choose
Secrets and Variables -> Actions in the left nav. Create a repository secret
called `RUBYGEMS_API_KEY` whose value is an API key from RubyGems with
"push rubygem" scope. You can also provide this secret at the organization
level.

## Release operations

This section describes how Toys-Release manages releases and how you control
and interact with the process.

Overall, the process looks like this:

1.  A maintainer schedules a release by triggering the "Open release request"
    GitHub Action. This action analyzes the repository, looking for changes in
    each component, deciding which components have releasable updates,
    determining the semver version bump for each, and building a changelog. It
    then opens a pull request with the version and changelog updates.

2.  The maintainer can either merge the pull request (possibly with manual
    modifications to the changelogs and/or version numbers to release) or close
    it unmerged.

3.  If the pull request is merged, the release is automatically processed by
    additional GitHub Actions. The automation verifies that the GitHub checks
    pass, and runs the release pipeline.

4.  The results of the run are reported back to the release pull request. If
    the release failed, a GitHub issue is also automatically opened. A
    maintainer can retry a failed release by triggering the "Retry release"
    GitHub Action.

### Requesting releases

To request a release, navigate to the Actions tab in the GitHub UI, select the
"Open release request" workflow, and click the "Run workflow" dropdown. This
will open a confirmation drop-down. Click the "Run workflow" button to confirm
and begin the automatic release analysis.

The dropdown provides an optional "Components to release" field. Often you can
leave this blank, and Toys-Release will analyze all components in the repository
and select the ones that have releasable changes pending. Alternatively, you
can choose which components to release by entering their names, space-delimited
in the field.

The field also supports setting the version number for each component, by
appending the version to the component name, separated by a colon.

For example, to request releases of the `toys` and `toys-release` components,
you can enter the following text into "Components to release":

    toys toys-release

To make the above request but specifically request version 0.3.0 of the
`toys-release` component:

    toys toys-release:0.3.0

### Managing release pull requests

You can also specify which components get released and at which versions, by
modifying the release pull request. You can change the version in the pull
request, or even revert the version/changelog change for some components and/or
introduce version/changelog modifications for other components. The releases
that ultimately take place are simply dictated by what changes get introduced
by the commit introduced by merging the pull request.

**Important:** If you modify a release pull request, be sure to *squash* your
changes when you merge it. It is important that the entire pull request is
expressed in a single commit, because the automation will look only at the
changes in the most recent commit after merge.

You will also notice that the pull request opened by the "Open release request"
workflow will have the `release: pending` label applied. This label signals the
release automation that this is a release pull request. If you remove this
label, the automation will not process the release.

Finally, you can even create a release pull request manually. You must simply
ensure that:

* The pull request has the `release: pending` label applied
* The pull request merges as a single commit (i.e. "squashed")
* For each component you want to release, the version and changelog are
  updated appropriately.

If you close a release pull request without merging, the release will be
canceled. The automation will apply the `release: aborted` label to indicate
this.

### Release results and logs

(TODO)

### Troubleshooting and retrying releases

(TODO)

### Documentation publication

(TODO)

### Special commit tags

(TODO)

### Running on the command line

(TODO)

## The release pipeline

Toys-Release features a highly configurable build pipeline. By default it is
configured to handle most RubyGems packages, and will:

* Tag and post a GitHub Release
* Build a RubyGems package and push it to rubygems.org
* Optionally build Yardoc documentation and push it to GitHub Pages

The pipeline system, however, lets you customize any aspect of the process, and
even replace it with an entirely different process altogether, possibly even
handling a completely different type of releasable artifact. This section
covers the build pipeline. See also the
[build step configuration](#build-step-configuration) section in the
configuration reference documentation.

### Pipeline steps

(TODO)

### Inter-step communication and dependencies

(TODO)

### The standard pipeline

(TODO)

### Custom steps

(TODO)

### Common pipeline modifications

(TODO)

## Configuration reference

The Toys-Release configuration file is a [YAML](https://yaml.org)-formatted
file located in your repository at `.toys/.data/releases.yml`. It controls all
aspects of the release process and behavior and is required.

This section will cover all keys in configuration file.

### Top level configuration

The top level of the yaml file is a dictionary that can include the following
keys. Out of these, **repo**, **git_user_name**, and **git_user_email** are all
required. The rest are optional.

* **append_steps**: *array of [BuildStepConfig](#build-step-configuration)* (optional) --
  A list of build steps to append to the end of the default build pipeline.
  This can be used to modify the default build pipeline instead of redefining
  the entire pipeline using the **steps** key.

* **breaking_change_header**: *string* (optional) --
  A changelog entry prefix that appears when a change is marked as breaking.
  Default is `BREAKING CHANGE`.

* **commit_tags**: *array of [CommitTagConfig](#commit-tag-configuration)* (optional) --
  A set of configurations defining how to interpret
  [conventional commit](https://conventionalcommits.org) tags, including how
  they trigger releases, bump versions, and generate changelog entries. See
  [commit tag configuration](#commit-tag-configuration) for details.
  If not included, Toys-Release will use a default configuration as follows:

      - tag: feat
        semver: minor
        header: ADDED
      - tag: fix
        semver: patch
        header: FIXED
      - tag: docs
        semver: patch

* **components**: *array of [ComponentConfig](#component-configuration)* (optional) --
  An array of releasable components, usually RubyGems packages. See
  [Component Configuration](#component-configuration) for details on the format
  of each component. You can also use the name **gems** for this config key.

* **coordinate_versions**: *boolean* (optional) --
  If set to true, this is a shorthand for setting up a coordination group
  containing all components in this repository. Defaults to *false*.

* **coordination_groups**: *array of array of string* (optional) --
  A list of disjoint sets of component names. Each set defines a group of
  components that will always be released together with the same version
  number. That is, if one or more components in a set are released, the entire
  set is released, even components with no changes. This is useful for sets of
  gems, such as the Rails gems, that are always released together.

* **enable_release_automation**: *boolean* (optional) --
  When enabled, the release pipeline runs automatically when a release pull
  request is merged. Defaults to *true*.

* **gh_pages_enabled**: *boolean* (optional) --
  Whether to globally enable gh-pages publication for all releases. Defaults to
  *false*.

* **git_user_email**: *string* (required) --
  The git `user.email` setting to use when making git commits.

* **git_user_name**: *string* (required) --
  The git `user.name` setting to use when making git commits.

* **main_branch**: *string* (optional) --
  The name of the main branch. Defaults to `main` if not provided.

* **modify_steps**: *array of [BuildStepModification](#build-step-modification)* (optional) --
  A set of modifications to the default build steps. This can be used to modify
  the default build pipeline instead of redefining the entire pipeline using
  the **steps** key.

* **no_significant_updates_notice**: *string* (optional) --
  A notice that appears in a changelog when a release is done but no other
  changelog entries are present. Default is `No significant updates.`

* **prepend_steps**: *array of [BuildStepConfig](#build-step-configuration)* (optional) --
  A list of build steps to prepend to the start of the default build pipeline.
  This can be used to modify the default build pipeline instead of redefining
  the entire pipeline using the **steps** key.

* **release_branch_prefix**: *string* (optional) --
  The prefix for all release branch names. Defaults to `release`.

* **release_aborted_label**: *string* (optional) --
  The name of the GitHub issue label that identifies aborted release pull
  requests. Defaults to `release: aborted`.

* **release_complete_label**: *string* (optional) --
  The name of the GitHub issue label that identifies successfully completed
  release pull requests. Defaults to `release: complete`.

* **release_error_label**: *string* (optional) --
  The name of the GitHub issue label that identifies release pull requests in
  an error state. Defaults to `release: error`.

* **release_pending_label**: *string* (optional) --
  The name of the GitHub issue label that identifies pending release pull
  requests. Defaults to `release: pending`.

* **repo**: *string* (required) --
  The GitHub repository name in the form `owner/repo`. For example, the Toys
  repo is `dazuma/toys`.

* **required_checks**: *regexp/boolean* (optional) --
  Identifies which GitHub checks must pass as a prerequisite for a release. If
  a string is provided, it is interpreted as a Ruby regexp (PCRE) and
  identifies the check names. A boolean value of *true* (the default) means all
  checks must pass. A boolean value of *false* disables checking.

* **required_checks_timeout**: *integer* (optional) --
  The time to wait, in seconds, for required checks to pass during release
  processing. Defaults to 900 (i.e. 15 minutes).

* **signoff_commits**: *boolean* (optional) --
  Whether to make commits with `--signoff`. Set this to true if your repository
  has a policy that commits require signoff. Defaults to *false*.

* **steps**: *array of [BuildStepConfig](#build-step-configuration)* (optional) --
  The build pipeline as a list of build steps. See
  [build step configuration](#build-step-configuration) for details on how to
  define the pipeline. If this is not included, Toys-Release will use a default
  pipeline as follows:

      - name: bundle
      - name: build_gem
      - name: build_yard
      - name: release_github
      - name: release_gem
        source: build_gem
      - name: push_gh_pages
        source: build_yard

### Commit tag configuration

A commit tag configuration specifies how the release system should handle a
particular [conventional commits](https://conventionalcommits.org) tag,
including what kind of [semver](https://semver.org) version bump it implies,
and how it should appear in the changelog. The format of the configuration is a
dictionary with the keys documented here. The **tag** key is required; the
remaining keys are optional and have defaults.

* **header**: *string,null* (optional) --
  A prefix that appears before each changelog entry generated by this tag. The
  special value *null* suppresses changelog entry generation for this scope.
  Defaults to the tag itself in all caps.

* **scopes**: *array of [ScopeConfig](#scope-configuration)* (optional) --
  Overrides for conventional commit scopes.

* **semver**: *string* (optional) --
  The semver version bump implied by changes of this type. Possible values are
  `patch`, `minor`, `major`, and `none`. Default is `none`.

* **tag**: *string* (required) -- The conventional commit tag.

#### Scope configuration

A scope configuration provides override behavior for a particular scope name
in a commit tag configuration. This lets you provide special behavior for
individual scopes. A common case might be `chore(deps):` which is used by some
dependency-updating bots. Typically, `chore:` does not indicate a significant
change that should trigger a release or appear in a changelog, but you might
choose different behavior for dependency changes.

* **header**: *string,null* (optional) --
  A prefix that appears before each changelog entry generated by this tag. The
  special value *null* suppresses changelog entry generation for this scope.
  Defaults to the same setting used by the tag.

* **scope**: *string* (required) -- The scope name.

* **semver**: *string* (optional) -- 
  The semver version bump implied by changes of this type. Possible values are
  `patch`, `minor`, `major`, and `none`. Defaults to the same setting used by
  the tag.

### Component configuration

A component configuration specifies how a particular component (often a
RubyGems package) should be released. Its format is a dictionary with the keys
documented here.

* **append_steps**: *array of [BuildStepConfig](#build-step-configuration)* (optional) --
  A list of build steps to append to the end of this component's build
  pipeline. This can be used to modify the build pipeline instead of redefining
  the entire pipeline using the **steps** key.

* **changelog_path**: *string* (optional) --
  The path to the component's changelog file, relative to the component's
  directory. Default is `CHANGELOG.md`.

* **directory**: *string* (optional) --
  The directory within the repository where this component is located. Defaults
  to the component name, unless there is exactly one component in this
  repository, in which case the default is the root of the repository, i.e.
  "`.`". This directory is used to identify when files related to this
  component have been changed, and is also used as a base directory for other
  paths related to the component.

* **exclude_globs**: *array of string* (optional) --
  An array of globs identifying files or directories that should be ignored
  when identifying changes to this component. These paths are relative to the
  repo root.

* **gh_pages_directory**: *string* (optional) --
  The directory in the `gh-pages` branch under which this component's
  documentation is published. The default is the component name.

* **gh_pages_enabled**: *boolean* (optional) --
  Whether gh-pages documentation publishing is enabled for this component.
  Default is *true* if either **gh_pages_directory** or **gh_pages_version_var**
  is set explicitly; otherwise *false*.

* **gh_pages_version_var**: *string* (optional) --
  The name of a Javascript variable within the `404.html` page under gh-pages
  that identifies the latest release of this component. Defaults to a variable
  name corresponding to the component name.

* **include_globs**: *array of string* (optional) --
  An array of globs identifying additional files or directories, not located in
  the component's directory itself, that should signal changes to this
  component. This can be used, for example, if the repo has global files shared
  by multiple components, where a change in such a file should trigger releases
  for all those components. These paths are relative to the repo root.

* **modify_steps**: *array of [BuildStepModification](#build-step-modification)* (optional) --
  A set of modifications to this component's build steps. This can be used to
  modify the build pipeline instead of redefining the entire pipeline using
  the **steps** key.

* **name**: *string* (required) --
  The name of the component, e.g. the name of the RubyGems package if this
  component represents a gem.

* **prepend_steps**: *array of [BuildStepConfig](#build-step-configuration)* (optional) --
  A list of build steps to prepend to the start of this component's build
  pipeline. This can be used to modify the build pipeline instead of redefining
  the entire pipeline using the **steps** key.

* **steps**: *array of [BuildStepConfig](#build-step-configuration)* (optional) --
  A way to override the complete build pipeline for this component. If not
  present, the default pipeline for the entire repository is used. (See the
  **steps** key under [Top level configuration](#top-level-configuration).)

* **version_constant**: *string* (optional) --
  The fully-qualified name of the version constant. This is used to determine
  the current version of the component. The default uses the module implied by
  the component name. For example, if the component (gem) name is
  `toys-release`, this defaults to `Toys::Release::VERSION`.

* **version_rb_path**: *string* (optional) --
  The path to a Ruby file that contains the current version of the component.
  This file *must* include Ruby code that looks like this:

      VERSION = "1.2.3"
  
  where the string is the latest released version. (Prior to the initial
  release, this version should be `0.0.0`.) Typically, `VERSION` is a constant
  defined in the "base module" for the Ruby library.

  The default is `version.rb` within the lib path associated with the Ruby
  module implied by the component name. For example, if the component (gem)
  name is `toys-release`, this defaults to `lib/toys/release/version.rb`.

### Build step configuration

A build step describes one step in the release process. Its format is a
dictionary with the keys described below. Specific types of build steps may
define additional keys as documented under the section
[build step types](#build-step-types). For more introductory information, see
the section on [the release pipeline](#the-release-pipeline) above.

* **name**: *string* (optional) --
  The unique name of this build step in the build pipeline. If not explicitly
  provided, a unique name will be generated.

* **type**: *string* (optional) --
  The type of build step, defining what it does. Possible values are:
  `build_gem`, `build_yard`, `bundle`, `command`, `noop`, `push_gh_pages`,
  `release_gem`, `release_github`, and `tool`. For more information, see the
  section [build step types](#build-step-types).

* **run**: *boolean* (optional) --
  Whether to force this step to run. Typically, build steps will run only if
  the build type determines that it should run, or if the step is a dependency
  of another step that will run. You can, however, force a step to run that
  would otherwise not do so by setting this key to *true*.

* **inputs**: *array of [InputConfig](#step-input-configuration)* (optional) --
  Inputs to this step, indicating dependencies on other steps and files to copy
  from those steps' outputs.

* **outputs**: *array of [OutputConfig](#step-output-configuration)* (optional) --
  Files to copy to this step's output so they become available to other steps.

#### Step input configuration

A step input represents a dependency on another step: if this step is run, the
other step will also be run. It also describes files that should be copied from
the dependent step's output and made available to the depending step. This
configuration is a dictionary supporting the following keys:

* **collisions**: *string* (optional) --
  A symbolic value indicating what to do if a collision occurs between incoming
  and existing files. Possible values are:

    * `error`: (the default) Abort with an error
    * `keep`: Keep the existing file
    * `replace`: Replace the existing file with the incoming file

* **dest**: *string or false* (optional) --
  A symbolic value indicating where to copy the dependent step's output to.
  Possible values are:

    * `component`: (the default) Copy files to the component directory
    * `repo_root`: Copy files to the repository root
    * `output`: Copy files to this step's output directory
    * `temp`: Copy files to this step's temp directory
    * `none`: Do not copy any files, but just declare a dependency

* **dest_path**: *string* (optional) --
  The path in the destination to copy to. If **source_path** is provided,
  **dest_path** is the corresponding path in the destination. If **source_path**
  is not provided, **dest_path** is a directory into which the source contents
  are copied. If **dest_path** is not provided, it defaults to the effective
  value of **source_path**, i.e. things are copied into the same locations
  within the destination as they were in the source.

* **name**: *string* (required) --
  The name of the step to depend on. The dependent step must be located earlier
  in the pipeline than the depending step.

* **source_path**: *string* (optional) --
  The path of the file or directory to copy from the source output. Only this
  item (recursively, if a directory) is copied. If this key is not provided,
  *all* contents of the source output are copied (e.g. the default is
  effectively "`.`")

#### Step output configuration

A step output represents files automatically copied to the step's output
directory after the step runs. This configuration is a dictionary supporting
the following keys:

* **collisions**: *string* (optional) --
  A symbolic value indicating what to do if a collision occurs between incoming
  and existing files. Possible values are:

    * `error`: (the default) Abort with an error
    * `keep`: Keep the existing file
    * `replace`: Replace the existing file with the incoming file

* **dest_path**: *string* (optional) --
  The path in the output directory to copy to. If **source_path** is provided,
  **dest_path** is the corresponding path in the output. If **source_path** is
  not provided, **dest_path** is a directory into which the source contents are
  copied. If **dest_path** is not provided, it defaults to the effective value
  of **source_path**, i.e. things are copied into the same locations within the
  output as they were in the source.

* **source**: *string* (optional) --
  A symbolic value indicating where to copy from. Possible values are:

    * `component`: (the default) Copy files from the component directory
    * `repo_root`: Copy files from the repository root
    * `temp`: Copy files from this step's temp directory

* **source_path**: *string* (optional) --
  The path of the file or directory to copy from the source. Only this item
  (recursively, if a directory) is copied. If this key is not provided, *all*
  contents of the source are copied (e.g. the default is effectively "`.`")

#### Build step types

This is a list of the available build step types, including their behavior and
any additional configuration keys supported by each.

* **build_gem** -- A step that builds a gem package.

  This step builds the gem described by the properly named gemspec file for
  this component. The built package file is copied to this step's output. Other
  steps (such as **release_gem**) can declare it as an input to get access to
  the built package. This step does not run unless it is so declared as a
  dependency or unless it is requested explicitly.

* **build_yard** -- A step that builds Yardocs.

  This step builds documentation using [YARD](https://yardoc.org). The built
  documentation is copied to this step's output in the directory `doc/`. Other
  steps (such as **push_gh_pages**) can declare it as an input to get access to
  the built documentation. This step does not run unless it is so declared as a
  dependency or unless it is requested explicitly.

  This step supports the following additional configuration keys:

    * **bundle_step**: *string* (optional) --
      The name of the bundle step. Defaults to `bundle`. This is used if the
      **uses_gems** key is *not* provided.

    * **uses_gems**: *array of (string or array of string)* (optional) --
      An array of gem specifications, each of which can be a simple gem name or
      an array including rubygems-style version requirements. These gems are
      provided to Yard, and can include gems such as `redcarpet` that may be
      needed for markup handling. If this key is included, the specified gems
      are installed directly; if not, the bundle step is declared as a
      dependency instead.

* **bundle** -- A step that installs the bundle in the component directory.

  This step copies the resulting `Gemfile.lock` to its output. Other steps can
  declare it as an input to get access to the `Gemfile.lock`. This step
  does not run unless it is so declared as a dependency or unless it is
  requested explicitly.

  This step supports the following additional configuration keys:

    * **chdir**: *string* (optional) --
      Change to the specified directory (relative to the component directory)
      when installing the bundle. By default, runs in the component directory.

* **command** -- A step that runs a command in the component directory.

  This step supports the following additional configuration keys:

    * **chdir**: *string* (optional) --
      Change to the specified directory (relative to the component directory)
      when running the command. By default, runs in the component directory.

    * **command**: *array of string* (required) --
      The command to run

    * **continue_on_error**: *boolean* (optional) --
      If *true*, continue to run the pipeline if the command exits abnormally.
      If *false* (the default), the pipeline aborts.

  This step does not run unless it is requested explicitly using the **run**
  configuration or it is declared as a dependency.

* **noop** -- A no-op step that does nothing. This type is usually configured
  with inputs and outputs and is used to collect or consolidate data from other
  steps.

  This step does not run unless it is requested explicitly using the **run**
  configuration or it is declared as a dependency.

* **push_gh_pages** -- A step that pushes documentation to the gh-pages branch.

  The documentation to publish should be under `doc/` in the output directory
  of a "source" step, normally the **build_yard** step. This source step is
  automatically declared as a dependency.

  This step supports the following additional configuration keys:

    * **source**: *string* (optional) --
      The name of the source step. Defaults to `build_yard`.

  This step runs if gh-pages publishing is enabled in the component.

* **release_gem** -- A step that pushes a gem package to rubygems.org.

  The package must be provided under `pkg/` in the output directory of a
  "source" step, normally the **build_gem** step. This source step is
  automatically declared as a dependency.

  This step supports the following additional configuration keys:

    * **source**: *string* (optional) --
      The name of the source step. Defaults to `build_gem`.

  This step runs if a correctly-named gemspec file is present in the component
  directory.

* **release_github** -- A step that creates a git tag and GitHub release.

  This step always runs if present in the pipeline.

* **tool** -- A step that runs a Toys tool in the component directory.

  This step supports the following additional configuration keys:

    * **chdir**: *string* (optional) --
      Change to the specified directory (relative to the component directory)
      when running the tool. By default, runs in the component directory.

    * **continue_on_error**: *boolean* (optional) --
      If *true*, continue to run the pipeline if the tool exits abnormally. If
      *false* (the default), the pipeline aborts.

    * **tool**: *array of string* (required) --
      The tool to run

  This step does not run unless it is requested explicitly using the **run**
  configuration or it is declared as a dependency.

#### Build step modification

A build step modification is a dictionary that modifies one or more existing
steps in the build pipeline. Its format is a dictionary with the keys described
below.

The **name** and **type** fields filter the steps to modify. If neither is
provided, *all* steps are modified.

* **name**: *string* (optional) --
  Modify only the step with this unique name.

* **type**: *string* (optional) --
  Modify only steps matching this type.

All other keys represent changes to the configuration of matching steps. You
can provide either the *null* value to delete the key, or a new full value for
the key. See [build step configuration](#build-step-configuration) and
[build step types](#build-step-types) for details on the available keys and
their formats.
