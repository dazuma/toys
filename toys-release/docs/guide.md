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

 *  Installing a Toys tool;
 *  Writing a configuration file;
 *  Defining a set of GitHub Actions workflows and a set of GitHub labels
    (a tool is provided to perform this step); and
 *  Providing necessary credentials.

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

1.  During development, commit messages for all commits should be formatted
    according to the [Conventional Commits](https://conventionalcommits.org)
    standard. This allows Toys-Release (and other similar tools) to interpret
    the semantics of your changes and configure releases accordingly.

2.  A maintainer schedules a release by triggering the "Open release request"
    GitHub Action. This action analyzes the repository, looking for changes in
    each component, deciding which components have releasable updates,
    determining the semver version bump for each, and building a changelog. It
    then opens a pull request with the version and changelog updates.

3.  The maintainer can either merge the pull request (possibly with manual
    modifications to the changelogs and/or version numbers to release) or close
    it unmerged.

4.  If the pull request is merged, the release is automatically processed by
    additional GitHub Actions. The automation verifies that the GitHub checks
    pass, and runs the release pipeline.

5.  The results of the run are reported back to the release pull request. If
    the release failed, a GitHub issue is also automatically opened. A
    maintainer can retry a failed release by triggering the "Retry release"
    GitHub Action.

### Commit message formatting

When using Toys-Release, you should format all commit messages according to the
[Conventional Commits](https://conventionalcommits.org) standard. This allows
Toys-Release (and other similar tools) to interpret the semantics of your
changes and configure releases accordingly. (Even if you are not using such
tools, Conventional Commits encapsulates good best practice for writing useful
commit messages.) Properly formatted conventional commit messages will
determine what kind of version bump Toys-Release uses when releasing those
changes, and the commit messages themselves will be used in the changelog that
Toys-Release generates.

Specifically, a change that adds a new feature, corresponding to a minor update
under [Semantic Versioning](https://semver.org), should have a commit message
tagged with `feat:`. For example:

```
feat: You can now upload a cat photo
```

A change that fixes a bug, corresponding to a patch change under Semver, should
have a commit message tagged with `fix:`. For example:

```
fix: The app no longer crashes when a photo includes a dog instead of a cat
```

A change that updates documentation should have a commit message tagged with
`docs:`. For example:

```
docs: Emphasize that photos should include cats rather than dogs
```

A breaking change, which would trigger a major update under Semver, can be
expressed using either the `BREAKING CHANGE:` tag, or an exclamation mark after
any other type of tag. Here are a few examples:

```
BREAKING CHANGE: Rename the "add-photo" API to "add-cat-photo"
feat!: Raise an exception if a photo contains a dog instead of a cat
```

A change that does not actually make any functional change, such as a git
repository configuration change, a CI change, or other admin-level change,
should be tagged with `chore:`. For example:

```
chore: Attach a photo of a cat to the repo
```

Other common tags might include `refactor:`, `style:`, `test:`, and others. See
https://conventionalcommits.org for more details and discussion.

By default, Toys-Release specifically recognizes the `feat:`, `fix:`, and
`docs:` tags, and uses them to configure releases and new versions. It also
recognizes breaking changes. It considers other tags to be non-significant for
release purposes. However, you can configure this behavior using the
**commit_tags** configuration field. See the
[configuration reference](#configuration-reference) for more details.

It is legal to have multiple conventional commit formatted messages in a single
commit message. Toys-Release will parse each commit message and use all
properly formatted conventional commit messages it finds. In most cases,
however, it is good practice to keep commits small and describable via a single
conventional commit message.

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

```sh
toys toys-release
```

To make the above request but specifically request version 0.3.0 of the
`toys-release` component:

```sh
toys toys-release:0.3.0
```

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

Finally, you can even create a release pull request manually, or using your own
tools or processes. You must simply ensure that:

 *  The pull request has the `release: pending` label applied
 *  The pull request merges as a single commit (i.e. "squashed")
 *  For each component you want to release, the version and changelog are
    updated appropriately.

If you close a release pull request without merging, the release will be
canceled. The automation will apply the `release: aborted` label to indicate
this.

### Monitoring progress and results

After a release pull request is merged, a GitHub Actions workflow will trigger
and begin processing the release. You can follow the workflow logs if you want
detailed information on the progress of the release. Additionally, updates will
be posted to the pull request when the workflow begins and when it completes.
These updates will include a link to the workflow logs for your convenience.

After a workflow finishes, it will apply a label to the pull request indicating
the final result. A successful release will have the `release: complete` label,
while an unsuccessful release will have the `release: error` label. If an error
occurred, the workflow will also open an issue in the repository reporting the
failed release.

Most of the useful workflow logs will appear in the "Process release request"
job under the workflow. If you follow the logs, you will see the release goes
through the following stages:

 *  First, it publishes a comment to the pull request indicating that the
    release is starting.
 *  Second, it polls the GitHub checks for the merge commit. Toys-Release will
    perform a release only if all required checks pass, so the release job will
    wait for them to complete. If any checks fail, the release will fail.
 *  Third, it runs a set of sanity checks, for example that it is looking at
    the correct repository and commit, that there are no locally modified
    files, and that the version numbers are set as expected.
 *  Next, it runs the release pipeline itself. It first does an analysis of
    which steps in the pipeline should run, then runs those steps in order.
 *  Finally, it publishes a comment to the pull request reporting the final
    result of the release.

### Troubleshooting and retrying releases

If a release fails, generally an issue will be opened in the repository, and
the pull request will have the `release: error` label applied. Releases can
fail for a number of reasons, including:

 *  The GitHub checks for the commit representing the merge of the release pull
    request, have failed or did not complete in a timely manner.
 *  A failure during the release pipeline, such as an error during the build or
    publication of a release artifact.
 *  An intermittent failure of the release pipeline infrastructure, such as a
    failure to obtain a VM to execute a GitHub Actions workflow.

If a failure occurs, the release workflow may have published some basic
information on the cause, to the release pull request. You can also find more
detailed information in the release logs, a link to which should also have been
published in the pull request comments. You should use this information to
troubleshoot the release.

In many cases, you can retry the release, possibly after doing something to
address the cause. For example, if the release failed because of a flaky test
in the GitHub checks, you can rerun the check, and once it passes, retry the
release. Or, if the release failed because of expired RubyGems credentials, you
can rotate the credentials (see [above](#provide-credentials)) and then retry
the release.

To retry a release, navigate to the Actions tab in the GitHub UI, select the
"Retry release" workflow, and click the "Run workflow" dropdown. This will open
a confirmation drop-down with a field for "Release PR number". Enter the number
of the *release pull request* here, and then click the "Run workflow" button to
retry the release.

When a failure takes place, it is possible that the release partially completed
but did not fully complete. For example, a GitHub release and tag may already
have been created, but the gem was not successfully pushed to RubyGems. When
you retry a release, the release script will automatically detect which release
steps were already completed, and will skip them.

If you need to "roll back" a failed release so it can be retried from a
different commit, currently you must manually roll back the version number and
changelog modification (i.e. roll back the changes in the release pull
request). You might also need to remove an existing GitHub tag and release if
they were already created.

## Other features

### Documentation publication

One of the optional features of the release pipeline is publication of Yardoc
reference documentation to GitHub Pages. This lets you host reference
documentation for your Ruby gem on your GitHub Pages site, under github.io. As
an example, of what this looks like you can see the reference documentation for
the Toys gem at https://dazuma.github.io/toys/gems/toys.

The features of this system are:

 *  Host generated Yardoc (or rdoc) documentation for every version of the gem.
 *  Host documentation for multiple gems per repository.
 *  Permanent GitHub Pages (github.io) URL for each gem, which redirects to the
    documentation for the latest version.
 *  Automatically publish documentation with each release.

#### Setting up documentation publication

To set up documentation, do the following:

 *  [Install the release tool](#install-the-release-tool) as documented in the
    main setup procedure. This provides access to the Toys-Release command line.

 *  Make sure you have a release config file. See the section on
    [writing the configuration file](#write-the-configuration-file) for how to
    get started here.

 *  For each gem that you want documented, include the configuration setting
    `gh_pages_enabled: true` in the component's configuration. Alternately, you
    can set `gh_pages_enabled: true` at the top level of the configuration file
    to enable documenting for all components.

 *  Create a starting gh-pages branch by running:

    ```sh
    toys release gen-gh-pages
    ```

    This will generate the gh-pages branch and push some key files to it,
    notably a `404.html` that does the redirecting to the latest documentation
    version. This may clobber any other gh-pages that you have present.

From this point on, any releases you do should also publish documentation to
your page. To find the page, use the URL
`https://<github-user>.github.io/<repo-name>/<component-name>`.

If you add or otherwise change your components, you can rerun the
`toys release gen-gh-pages` script to regenerate the files and update the
redirects. This will not affect any actual documentation you may have generated
previously.

#### Special configuration

There are a few configuration fields that affect documentation publication.

 *  **gh_pages_directory** is the directory name for this component in the
    documentation URL. This takes the place of the `<component-name>` in the
    URL. For example, if you set `gh_pages_directory: foo/bar` for your
    component, the documentation will be generated under the URL:
    `https://<github-user>.github.io/<repo-name>/foo/bar`.

    Note that if you modify this field after previously generating
    documentation for some releases, you will need to manually move the
    previous documentation into the new directory.

 *  **gh_pages_version_var** is the name of the Javascript variable in the
    `404.html` file that stores the latest version of this component's release.
    You will generally not need to modify this unless the
    automatically-generated variable name isn't unique for some reason.

See the [component configuration](#component-configuration) section for more
details.

### Special commit messages

Several special cases can be handled via commit tags that are defined by
Toys-Release. These conventional commit messages can appear in a commit message
and affect the behavior of that and other commits.

 *  **semver-change:** This tag forces a certain semver change to apply to this
    commit even if other commit tags say otherwise. For example, if a commit
    describes a new feature, but you want it released as a patch version bump
    rather than a minor version bump, you can include `semver-change: patch` in
    the commit message. The full commit message might read thus:

    ```
    feat: Add a small button that doesn't do a lot
    semver-change: patch
    ```

    Valid values for semver-change are `patch`, `minor`, `major`, and `none`.

    The semver-change tag affects only the commit it is part of. If multiple
    commits are included in a release, other commits in the release might still
    upgrade the version bump to minor or higher.

 *  **revert-commit:** This tag indicates that the commit reverts, and thus
    nullifies the effect of, an earlier commit, thus removing any version bump
    and any changelog entries that would otherwise have been generated. Use the
    SHA of the earlier commit as the content of the tag. For example:

    ```
    revert-commit: b10c6fb3363bd1335dcfbd671bdceae53cd55716
    ```

    A commit can combine revert-commit with other conventional commit tags. It
    can even include multiple revert-commit tags if the commit reverts more than
    one previous commit.

 *  **touch-component:** This tag indicates that the commit should be treated
    as if it touches a specified component, even if it does not actually modify
    that component's files. For example:

    ```
    fix: Fix the build
    touch-component: my_gem
    ```

 *  **no-touch-component:** This tag indicates that the commit should be
    treated as if it does *not* touch a specified component, even if it
    modifies that component's files. For example:

    ```
    fix: Fix the build
    no-touch-component: my_gem
    ```

### Running on the command line

The implementation of Toys-Release is done via Toys (i.e. command line) tools.
In most cases, you will use the GitHub Actions integration to manage your
releases, but you can also run the tools directly from the command line.

To do so, first make sure you have
[installed the release tool](#install-the-release-tool) as documented in the
main setup procedure. Then, the command line tools will be available as
subtools underneath `toys release`. For example, you could request a release
from the command line instead of a GitHub Action, by running the command
`toys release request`, and providing it the needed arguments and credentials.

As with all Toys-based tools, you can pass `--help` to any tool to get detailed
usage information. For example: `toys release request --help`. You can also run
`toys release --help` for a list of all the release-related tools.

The following are the available command line tools. You may recognize some of
these as tools you used during the [installation](#installation) procedure.

 *  **create-labels** Creates the GitHub labels used by the release system

 *  **gen-config** Generates an initial release configuration file

 *  **gen-gh-pages** Initializes the gh-pages branch for publishing
    documentation

 *  **gen-workflows** Generates the GitHub Actions workflows used by
    Toys-Release

 *  **perform** Runs the release pipeline from the command line. Assumes you
    have already updated the version number and the changelog.

 *  **request** Analyzes the repository history and opens a release pull
    request including any pending releases. This is the command line tool used
    by the "Open release request" GitHub Action.

 *  **retry** Retries a failed release. This is the command line tool used by
    the "Retry release" GitHub Action.

There are also internal (hidden) subtools called "_onclosed" and "_onpush".
These are the tools called by GitHub Actions automation in response to pull
request events, and you should generally not call them directly.

## The release pipeline

Toys-Release features a highly configurable build pipeline. By default it is
configured to handle most RubyGems packages, and will:

 *  Tag and post a GitHub Release
 *  Build a RubyGems package and push it to rubygems.org
 *  Optionally build Yardoc documentation and push it to GitHub Pages

The pipeline system, however, lets you customize any aspect of the process, and
even replace it with an entirely different process altogether, possibly even
handling a completely different type of releasable artifact. This section
covers the build pipeline. See also the
[build step configuration](#build-step-configuration) section in the
configuration reference documentation.

### Pipeline steps

A release pipeline is defined as an ordered series of **steps**. Each of these
steps may perform some task and/or exchange some data with other steps. For
example, a step might install a bundle, another might build a gem package, and
another might push a gem package built by a previous step to rubygems.org.

The behavior of a step is determined by the **type** of the step, and by
additional **configuration attributes** provided to the step. Each step also
has a unique **name** that lets you identify it and connect it to other steps.

When a pipeline is run, individual steps in the pipeline may or may not
actually execute, depending on whether they are needed. For example, the step
type that creates a GitHub release will always run if it is present in a
pipeline, but the step type that installs the bundle will normally run only if
another subsequent step *that will run* actually needs the bundle, and the step
type that builds the gem package will normally run only if a subsequent step
*that will run* actually uses the built package (e.g. to push it to RubyGems.)
The decision of whether or not a step will run depends on the step's
configuration, and the step dependencies configured into the pipeline.

We will cover, as an example, the [standard pipeline](#the-standard-pipeline)
for RubyGems releases below. First, however, we need to discuss how steps
depend on one another and pass data around.

### Inter-step communication and dependencies

When a step runs, the working directory is set to the **component directory**
in a *clean* checkout of the release SHA in the repository. Any changes it
makes to the repository working directory are *not* preserved for other steps;
instead, it must explicitly "output" any files it needs to make available, and
other steps must explicitly access those files as "inputs". This is sometimes
done by the step's code, but can also be specified in the step's configuration.

For example, a step that builds a gem package should "output" the package so
that it is available to other steps that want to publish it. This simply
involves copying the relevant files to a special directory known as the output
directory for that step (identified by step name). The standard **build_gem**
step type does this in code. Alternatively, if you write a custom step that
builds an artifact, you can specify, via the **outputs** configuration, the
artifacts that you want made available. (See the
[output config reference](#step-output-configuration) for details.)

Then, a step can use a built artifact previously output by another step by
copying it from the previous step's output directory. Again, this can be done
in code, as by the standard **release_gem** step type. You can also specify,
via the **inputs** configuration, artifacts to copy from another step's output
into your working directory. (For details, see the
[input config reference](#step-input-configuration).)

When a step specifies the **inputs** configuration, any steps so referenced are
also automatically tagged as *dependencies* of the step. If the pipeline
determines the step should be run, then its dependencies are also marked as to
be run.

#### Inter-step communication example

Consider the following simple, if contrived, pipeline:

```yaml
- name: create_file
  type: command
  command: ["touch", "my-file.txt"]
  outputs:
    - source_path: my-file.txt
- name: create_another_file
  type: command
  command: ["touch", "another-file.txt"]
  outputs:
    - source_path: another-file.txt
- name: show_file
  type: command
  command: ["cat", "my-file.txt"]
  inputs:
    - name: create_file
      source_path: my-file.txt
  run: true
```

This pipeline includes three steps. After each step, the git repository gets
reset, so any files created by the step are not initially available to
subsequent steps unless the step explicitly accesses them via inputs. Also note
that all three steps are of type "command", which do not run by default unless
something else causes them to run.

Let's consider these steps starting with the last one.

The third step, named `show_file`, looks for a file `my-file.txt` in the
*first* step's outputs, copies it into its working directory, and prints its
contents to the logs. It includes the `run: true` configuration which forces it
to run.

Because the third step, `show_file`, copies an input from the first step,
`create_file`, the latter is a dependency of the former. And since the
`show_file` is forced to run, then `create_file` will also run. This step will
run first, because it is first in the list of steps, and it will create a file
and copy it to its outputs so the `show_file` can access it.

The second step, `create_another_file`, would create another file and copy it
to its outputs. However, it neither is forced to run via `run: true` nor is
listed as a dependency of any other step that will run. Therefore, the second
step never runs at all.

### The standard pipeline

The default release pipeline illustrates the above features of steps. It
includes the following steps:

 *  **bundle**: Installs the bundle, and copies the `Gemfile.lock` to its
    output directory. This step runs because the later step **build_yard**
    declares it as a dependency and accesses the `Gemfile.lock`.
 *  **build_gem**: Builds the gem package, and copies the package file to its
    output directory. This step runs because the later step **release_gem**
    declares it as a dependency and accesses the built package.
 *  **build_yard**: Builds the Yardoc documentation. By default, this step uses
    the `yard` gem from the bundle, and thus depends on the earlier **bundle**
    step. It copies the `Gemfile.lock` output by the earlier step. After
    building the documentation into the `doc` directory, it copies that
    directory to its output directory. This step runs *if* the later step
    **push_gh_pages**, which lists it as a dependency, runs.
 *  **release_github**: Pushes a release tag to GitHub and creates a GitHub
    release. This step always runs and has no dependencies.
 *  **release_gem**: Pushes the built gem package to rubygems.org. This step
    lists the earlier **build_gem** step as a dependency, and copies the built
    gem package from that step's output.
 *  **push_gh_pages**: Pushes the built documentation to the `gh-pages` branch
    so it shows up on the repository's GitHub Pages site. This step runs only
    if the repository actually has a `gh-pages` branch and the release
    configuration specifies that it should be pushed to. If this step does run,
    it lists the earlier **build_yard** step as a dependency, and copies the
    built documentation from that step's output.

Ultimately, this pipeline will create a GitHub release, push a RubyGems
package, and optionally push documentation.

### Modifying the pipeline

If your releases have different requirements, you can modify the release
pipeline, by inserting steps, by modifying existing steps, or by replacing the
entire pipeline with a new pipeline. These modifications can be made globally
for all releases in a repository, or specifically for individual releasable
components, by adding configuration at the top level of the configuration (see
the [top level configuration reference](#top-level-configuration)) or
underneath a particular component's configuration (see the
[component configuration reference](#component-configuration)).

 *  To insert new steps, at the beginning or end of the pipeline, or before or
    after specific named steps, use the **append_steps** and **prepend_steps**
    configurations.
 *  To modify existing steps, use the **modify_steps** configuration. See the
    reference on [build step modification](#build-step-modification).
 *  There is no specific way to delete an existing step. This is because a step
    might be referenced by other steps. To ensure a step does not run, you can
    modify it to change its type to `noop` (which has no behavior and does not
    run by default) and ensure that no step depends on it.
 *  If your changes are more complex than can reasonably be expressed by
    modifying the default pipeline, you can replace the pipeline completely
    using the **steps** configuration.

#### Pipeline modification example

The `toys` gem itself has a customized release pipeline. This pipeline includes
a step that merges key classes from `toys-core`, such as DSL classes, into the
documentation for the `toys` gem.

The merging is actually performed by a toys tool called `copy-core-docs`
defined in the directory for the `toys` gem. The implementation itself isn't
important; what's important is that we want this merging to be part of the
release process.

The `releases.yml` for the toys repository includes this configuration for the
`toys` gem:

```yaml
components:
  - name: toys
    prepend_steps:
      - name: copy_core_docs
        type: tool
        tool: [copy-core-docs]
        outputs: [core-docs]
    modify_steps:
      - name: build_yard
        inputs: [copy_core_docs]
      - name: build_gem
        inputs: [copy_core_docs]
```

Let's unpack what this is doing.

First, we note that we are not replacing the default pipeline completely; we
are only modifying it *for this one gem*. The other gems (`toys-core` and
`toys-release`) continue to use the default pipeline unmodified.

For the `toys` gem, then, we prepend one new step at the beginning of the
pipeline. The step is named `copy_core_docs`, and it runs the toys tool that
copies files (with some modifications to simplify them and make them suitable
for just documentation) from `toys-core` into the `toys` directory under the
`core-docs` subdirectory. This directory is not part of the include path, so
these files are not in the require path and do not interfere with the
functionality of the library. However, they are in the `.yardopts` file and are
used when documentation is built. We then copy this new directory to the
output for the `copy_core_docs` step, to preserve it for future steps.

Next, we modify the `build_yard` step to load the `copy_core_docs` output. This
brings those files back into our working directory when the Yardocs are built.
It also adds the `copy_core_docs` step to the dependencies of `build_yard` to
ensure it gets executed.

We also modify the `build_gem` step to load the `copy_core_docs` output. This
ensures that the files are also present when the gem is built, so that services
like rubydoc.info will have them available when they build the documentation.
Again, this also adds `copy_core_docs` to the dependencies of `build_gem`. As a
dependency of both `build_gem` and `build_yard`, this ensures that our new step
will indeed get executed. (It does not execute twice; Toys-Release ensures each
step is executed at most once, even if it is listed multiple times as a
dependency.)

#### Useful types for custom steps

The **command** and **tool** step types are both very useful when creating
custom steps. We've seen in the [example above](#pipeline-modification-example)
how a step of type **tool** is used in the customized release process for the
`toys` gem itself. The **command** type is similar; it executes a Unix command
rather than a Toys tool. These two types are very useful for performing
arbitrary behavior during a release.

Another step type that is occasionally useful is **noop**. This type has no
behavior; it doesn't *do* anything, but you can configure it with inputs and
outputs. This can be useful for consolidating data output by other steps. You
can, for example, configure a **noop** with multiple **inputs** from other
steps, configuring each input to copy to the noop's *output*. Now, all the
files from potentially multiple inputs are combined and can be referenced
conveniently via a single step's output.

See the reference below on [build step types](#build-step-types) for detailed
information on these and other step types and their configurations.

## Configuration reference

The Toys-Release configuration file is a [YAML](https://yaml.org)-formatted
file located in your repository at `.toys/.data/releases.yml`. It controls all
aspects of the release process and behavior and is required.

This section will cover all keys in configuration file.

### Top level configuration

The top level of the yaml file is a dictionary that can include the following
keys.

The **repo**, **git_user_name**, and **git_user_email** keys are required. The
rest are optional.

 *  **append_steps**: *array of [BuildStepConfig](#build-step-configuration)* (optional) --
    A list of build steps to append to the end of the default build pipeline.
    This can be used to modify the default build pipeline instead of redefining
    the entire pipeline using the **steps** key.

 *  **breaking_change_header**: *string* (optional) --
    A changelog entry prefix that appears when a change is marked as breaking.
    Default is `BREAKING CHANGE`.

 *  **commit_tags**: *array of [CommitTagConfig](#commit-tag-configuration)* (optional) --
    A set of configurations defining how to interpret
    [conventional commit](https://conventionalcommits.org) tags, including how
    they trigger releases, bump versions, and generate changelog entries. See
    [commit tag configuration](#commit-tag-configuration) for details.
    If not included, Toys-Release will use a default configuration as follows:

    ```yaml
    - tag: feat
      semver: minor
      header: ADDED
    - tag: fix
      semver: patch
      header: FIXED
    - tag: docs
      semver: patch
    ```

 *  **components**: *array of [ComponentConfig](#component-configuration)* (optional) --
    An array of releasable components, usually RubyGems packages. See
    [Component Configuration](#component-configuration) for details on the
    format of each component. You can also use the name **gems** for this
    config key.

 *  **coordinate_versions**: *boolean* (optional) --
    If set to true, this is a shorthand for setting up a coordination group
    containing all components in this repository. Defaults to *false*.

 *  **coordination_groups**: *array of array of string* (optional) --
    A list of disjoint sets of component names. Each set defines a group of
    components that will always be released together with the same version
    number. That is, if one or more components in a set are released, the
    entire set is released, even components with no changes. This is useful for
    sets of gems, such as the Rails gems, that are always released together.

 *  **enable_release_automation**: *boolean* (optional) --
    When enabled, the release pipeline runs automatically when a release pull
    request is merged. Defaults to *true*.

 *  **gh_pages_enabled**: *boolean* (optional) --
    Whether to globally enable gh-pages publication for all releases. Defaults
    to *false*.

 *  **git_user_email**: *string* (required) --
    The git `user.email` setting to use when making git commits.

 *  **git_user_name**: *string* (required) --
    The git `user.name` setting to use when making git commits.

 *  **issue_number_suffix_handling**: *string* (optional) --
    A code indicating what to do with issue number suffixes (e.g. `(#123)`)
    that GitHub inserts at the end of commit messages for pull request merges.
    Possible values are:

     *  `plain`: (the default) Retain the suffix as is
     *  `link`: Linkify the suffix
     *  `delete`: Delete the suffix

 *  **main_branch**: *string* (optional) --
    The name of the main branch. Defaults to `main` if not provided.

 *  **modify_steps**: *array of [BuildStepModification](#build-step-modification)* (optional) --
    A set of modifications to the default build steps. This can be used to
    modify the default build pipeline instead of redefining the entire pipeline
    using the **steps** key.

 *  **no_significant_updates_notice**: *string* (optional) --
    A notice that appears in a changelog when a release is done but no other
    changelog entries are present. Default is `No significant updates.`

 *  **prepend_steps**: *array of [BuildStepConfig](#build-step-configuration)* (optional) --
    A list of build steps to prepend to the start of the default build
    pipeline. This can be used to modify the default build pipeline instead of
    redefining the entire pipeline using the **steps** key.

 *  **release_branch_prefix**: *string* (optional) --
    The prefix for all release branch names. Defaults to `release`.

 *  **release_aborted_label**: *string* (optional) --
    The name of the GitHub issue label that identifies aborted release pull
    requests. Defaults to `release: aborted`.

 *  **release_complete_label**: *string* (optional) --
    The name of the GitHub issue label that identifies successfully completed
    release pull requests. Defaults to `release: complete`.

 *  **release_error_label**: *string* (optional) --
    The name of the GitHub issue label that identifies release pull requests in
    an error state. Defaults to `release: error`.

 *  **release_pending_label**: *string* (optional) --
    The name of the GitHub issue label that identifies pending release pull
    requests. Defaults to `release: pending`.

 *  **repo**: *string* (required) --
    The GitHub repository name in the form `owner/repo`. For example, the Toys
    repo is `dazuma/toys`.

 *  **required_checks**: *regexp/boolean* (optional) --
    Identifies which GitHub checks must pass as a prerequisite for a release.
    If a string is provided, it is interpreted as a Ruby regexp (PCRE) and
    identifies the check names. A boolean value of *true* means all checks must
    pass. A boolean value of *false* (the default) disables checking.

 *  **required_checks_timeout**: *integer* (optional) --
    The time to wait, in seconds, for required checks to pass during release
    processing. Defaults to 900 (i.e. 15 minutes).

 *  **signoff_commits**: *boolean* (optional) --
    Whether to make commits with `--signoff`. Set this to true if your
    repository has a policy that commits require signoff. Defaults to *false*.

 *  **steps**: *array of [BuildStepConfig](#build-step-configuration)* (optional) --
    The build pipeline as a list of build steps. See
    [build step configuration](#build-step-configuration) for details on how to
    define the pipeline. If this is not included, Toys-Release will use a
    default pipeline as follows:

    ```yaml
    - name: bundle
    - name: build_gem
    - name: build_yard
    - name: release_github
    - name: release_gem
      source: build_gem
    - name: push_gh_pages
      source: build_yard
    ```

    See the earlier section on [the standard pipeline](#the-standard-pipeline)
    for a detailed description of the behavior of this default pipeline.

### Commit tag configuration

A commit tag configuration specifies how the release system should handle a
particular [conventional commits](https://conventionalcommits.org) tag,
including what kind of [semver](https://semver.org) version bump it implies,
and how it should appear in the changelog. The format of the configuration is a
dictionary with the keys documented here.

The **tag** key is required. The others are optional.

 *  **header**: *string,null* (optional) --
    A prefix that appears before each changelog entry generated by this tag.
    The special value *null* suppresses changelog entry generation for this
    scope. Defaults to the tag itself in all caps.

 *  **scopes**: *array of [ScopeConfig](#scope-configuration)* (optional) --
    Overrides for conventional commit scopes.

 *  **semver**: *string* (optional) --
    The semver version bump implied by changes of this type. Possible values
    are `patch`, `minor`, `major`, and `none`. Default is `none`.

 *  **tag**: *string* (required) -- The conventional commit tag.

#### Scope configuration

A scope configuration provides override behavior for a particular scope name
in a commit tag configuration. This lets you provide special behavior for
individual scopes. A common case might be `chore(deps):` which is used by some
dependency-updating bots. Typically, `chore:` does not indicate a significant
change that should trigger a release or appear in a changelog, but you might
choose different behavior for dependency changes.

The **scope** key is required. The others are optional.

 *  **header**: *string,null* (optional) --
    A prefix that appears before each changelog entry generated by this tag.
    The special value *null* suppresses changelog entry generation for this
    scope. Defaults to the same setting used by the tag.

 *  **scope**: *string* (required) -- The scope name.

 *  **semver**: *string* (optional) -- 
    The semver version bump implied by changes of this type. Possible values
    are `patch`, `minor`, `major`, and `none`. Defaults to the same setting
    used by the tag.

### Component configuration

A component configuration specifies how a particular component (often a
RubyGems package) should be released. Its format is a dictionary with the keys
documented here. Note that some keys can override global settings of the same
name.

The **name** key is required. The others are optional.

 *  **append_steps**: *array of [BuildStepConfig](#build-step-configuration)* (optional) --
    A list of build steps to append to the end of this component's build
    pipeline. This can be used to use the default build pipeline as a starting
    point and define modifications specific to this component, instead of
    redefining the entire pipeline using the **steps** key.

 *  **breaking_change_header**: *string* (optional) --
    A changelog entry prefix that appears when a change is marked as breaking.
    If not set, falls back to the [global setting](#top-level-configuration) of
    the same name.

 *  **changelog_path**: *string* (optional) --
    The path to the component's changelog file, relative to the component's
    directory. Default is `CHANGELOG.md`.

 *  **commit_tags**: *array of [CommitTagConfig](#commit-tag-configuration)* (optional) --
    A set of configurations defining how to interpret
    [conventional commit](https://conventionalcommits.org) tags, including how
    they trigger releases, bump versions, and generate changelog entries. See
    [commit tag configuration](#commit-tag-configuration) for details.
    If not set, falls back to the [global setting](#top-level-configuration) of
    the same name.

 *  **delete_steps**: *array of String* (optional) --
    A list of build step names to delete for this component. This can be used
    to use the default build pipeline as a starting point and define
    modifications specific to this component, instead of redefining the entire
    pipeline using the **steps** key.

 *  **directory**: *string* (optional) --
    The directory within the repository where this component is located.
    Defaults to the component name, unless there is exactly one component in
    this repository, in which case the default is the root of the repository,
    i.e. "`.`". This directory is used to identify when files related to this
    component have been changed, and is also used as a base directory for other
    paths related to the component.

 *  **exclude_globs**: *array of string* (optional) --
    An array of globs identifying files or directories that should be ignored
    when identifying changes to this component. These paths are relative to the
    repo root.

 *  **gh_pages_directory**: *string* (optional) --
    The directory in the `gh-pages` branch under which this component's
    documentation is published. The default is the component name.

 *  **gh_pages_enabled**: *boolean* (optional) --
    Whether gh-pages documentation publishing is enabled for this component.
    Default is *true* if either **gh_pages_directory** or
    **gh_pages_version_var** is set explicitly; otherwise falls back to the
    [global setting](#top-level-configuration) of the same name.

 *  **gh_pages_version_var**: *string* (optional) --
    The name of a Javascript variable within the `404.html` page under gh-pages
    that identifies the latest release of this component. Defaults to an
    auto-generated variable name corresponding to the component name.

 *  **include_globs**: *array of string* (optional) --
    An array of globs identifying additional files or directories, not located
    in the component's directory itself, that should signal changes to this
    component. This can be used, for example, if the repo has global files
    shared by multiple components, where a change in such a file should trigger
    releases for all those components. These paths are relative to the repo
    root.

 *  **issue_number_suffix_handling**: *string* (optional) --
    A code indicating what to do with issue number suffixes (e.g. `(#123)`)
    that GitHub inserts at the end of commit messages for pull request merges.
    If not set, falls back to the [global setting](#top-level-configuration) of
    the same name. Possible values are:

     *  `plain`: Retain the suffix as is
     *  `link`: Linkify the suffix
     *  `delete`: Delete the suffix

 *  **modify_steps**: *array of [BuildStepModification](#build-step-modification)* (optional) --
    A set of modifications to this component's build steps. This can be used to
    use the default build pipeline as a starting point and define modifications
    specific to this component, instead of redefining the entire pipeline using
    the **steps** key.

 *  **name**: *string* (required) --
    The name of the component, e.g. the name of the RubyGems package if this
    component represents a gem.

 *  **no_significant_updates_notice**: *string* (optional) --
    A notice that appears in a changelog when a release is done but no other
    changelog entries are present. If not set, falls back to the
    [global setting](#top-level-configuration) of the same name.

 *  **prepend_steps**: *array of [BuildStepConfig](#build-step-configuration)* (optional) --
    A list of build steps to prepend to the start of this component's build
    pipeline. This can be used to use the default build pipeline as a starting
    point and define modifications specific to this component, instead of
    redefining the entire pipeline using the **steps** key.

 *  **steps**: *array of [BuildStepConfig](#build-step-configuration)* (optional) --
    A way to override the complete build pipeline for this component. If not
    present, the default pipeline for the entire repository is used. (See the
    **steps** key under [Top level configuration](#top-level-configuration).)

 *  **update_dependencies**: *[UpdateDepsConfig](#update-dependencies-configuration)* (optional) --
    Set up automatic dependency updates, which causes this component to be
    updated and released if any of a specified set of dependencies is also
    present in the release. This supports automatically keeping "kitchen sink"
    libraries up to date. If this setting is not present, automatic updating is
    not performed for this component.

 *  **version_rb_path**: *string* (optional) --
    The path to a Ruby file that contains the current version of the component.
    This file *must* include Ruby code that looks like this:

    ```ruby
    VERSION = "1.2.3"
    ```
  
    where the string is the latest released version. (Prior to the initial
    release, this version should be `0.0.0`.) Typically, `VERSION` is a
    constant defined in the "base module" for the Ruby library.

    The default is `version.rb` within the lib path associated with the Ruby
    module implied by the component name. For example, if the component (gem)
    name is `toys-release`, this defaults to `lib/toys/release/version.rb`.

#### Update dependencies configuration

An update-dependencies configuration describes when a component should also be
released with updated dependency versions, due to one or more of those
dependencies being released. It is typically used to keep "kitchen sink"
libraries up to date.

For example, consider two components "foo_a" and "foo_b", and a "kitchen sink"
component "foo_all" that depends on both the others. Suppose whenever a patch
or greater release of either "foo_a" or "foo_b" happens, we also want "foo_all"
to be released with its corresponding dependency bumped to the same version. We
might set up the configuration like so:

```yaml
components:
  - name: foo_a
  - name: foo_b
  - name: foo_all
    update_dependencies:
      dependency_semver_threshold: patch
      dependencies: [foo_a, foo_b]
```

The update-dependencies configuration for a kitchen sink component can include
the following keys. The **dependencies** key is required. All others are
optional.

 *  **dependencies**: *array of string* (required) --
    A list of names of the components this component depends on.

 *  **dependency_semver_threshold**: *string* (optional) --
    The minimum semver level of a dependency update that should trigger an
    update of the kitchen sink component. For example, a threshold of `minor`
    would trigger an update to the kitchen sink if a minor release of a
    dependency occurred, but would not trigger an update to the kitchen sink if
    a patch release occurred.

    Allowed values are `major`, `minor`, `patch`, `patch2`, and `all`. The
    `all` value indicates that every release of a dependency should trigger an
    update to the kitchen sink. Defaults to `minor` if not specified.

 *  **pessimistic_constraint_level**: *string* (optional) --
    The highest semver level allowed to float in the pessimistic dependency
    version constraints used to specify the dependencies. For example, a
    version constraint of `~> 1.0` has level `minor` because the minor version
    number is allowed to float, whereas the major version number is pinned.

    Allowed values are `major`, `minor`, `patch`, `patch2`, and `exact`. The
    `exact` value indicates that dependencies should require the exact release
    version. Defaults to `minor` if not specified.

### Build step configuration

A build step describes one step in the release process. Its format is a
dictionary with the keys described below. Specific types of build steps may
define additional keys as documented under the section
[build step types](#build-step-types). For more introductory information, see
the section on [the release pipeline](#the-release-pipeline) above.

All keys are optional.

 *  **name**: *string* (optional) --
    The unique name of this build step in the build pipeline. If not explicitly
    provided, a unique name will be generated.

    In simple pipelines, there is often exactly one step of a given type (such
    as `release_github`). Because the type defaults to the name, it is common
    practice in such cases to simply set the name the desired type.

 *  **type**: *string* (optional) --
    The type of build step, defining what it does. Possible values are:
    `build_gem`, `build_yard`, `bundle`, `command`, `noop`, `push_gh_pages`,
    `release_gem`, `release_github`, and `tool`. For more information, see the
    section [build step types](#build-step-types). If the type is not set
    explicitly, it is set to the name. If the name is also not set explicitly,
    the type defaults to `noop`.

 *  **run**: *boolean* (optional) --
    Whether to force this step to run. Typically, build steps will run only if
    the build type determines that it should run, or if the step is a
    dependency of another step that will run. You can, however, force a step to
    run that would otherwise not do so by setting this key to *true*.

 *  **inputs**: *array of [InputConfig](#step-input-configuration)* (optional) --
    Inputs to this step, indicating dependencies on other steps and files to
    copy from those steps' outputs.

 *  **outputs**: *array of [OutputConfig](#step-output-configuration)* (optional) --
    Files to copy to this step's output so they become available to other steps.

#### Step input configuration

A step input represents a dependency on another step: if this (depending) step
is run, that other (dependent) step will also be run. It also describes files
that should be copied from the dependent step's output and made available to
the depending step. This configuration is a dictionary with the keys described
below.

The **name** key is required. The others are optional.

 *  **collisions**: *string* (optional) --
    A symbolic value indicating what to do if a collision occurs between
    incoming and existing files. Possible values are:

     *  `error`: (the default) Abort with an error
     *  `keep`: Keep the existing file
     *  `replace`: Replace the existing file with the incoming file

 *  **dest**: *string or false* (optional) --
    A symbolic value indicating where to copy the dependent step's output to.
    Possible values are:

     *  `component`: (the default) Copy files to the component directory
     *  `repo_root`: Copy files to the repository root
     *  `output`: Copy files to this step's output directory
     *  `temp`: Copy files to this step's temp directory
     *  `none`: Do not copy any files, but just declare a dependency

 *  **dest_path**: *string* (optional) --
    The path in the destination to copy to. If **source_path** is provided,
    **dest_path** is the corresponding path in the destination. If
    **source_path** is not provided, **dest_path** is a directory into which
    the source contents are copied. If **dest_path** is not provided, it
    defaults to the effective value of **source_path**, i.e. things are copied
    into the same locations within the destination as they were in the source.

 *  **name**: *string* (required) --
    The name of the step to depend on. The dependent step must be located
    earlier in the pipeline than the depending step.

 *  **source_path**: *string* (optional) --
    The path of the file or directory to copy from the source output. Only this
    item (recursively, if a directory) is copied. If this key is not provided,
    *all* contents of the source output are copied (e.g. the default is
    effectively "`.`")

#### Step output configuration

A step output represents files automatically copied to the step's output
directory after the step runs. This configuration is a dictionary supporting
the keys described below.

All keys are optional.

 *  **collisions**: *string* (optional) --
    A symbolic value indicating what to do if a collision occurs between incoming
    and existing files. Possible values are:

     *  `error`: (the default) Abort with an error
     *  `keep`: Keep the existing file
     *  `replace`: Replace the existing file with the incoming file

 *  **dest_path**: *string* (optional) --
    The path in the output directory to copy to. If **source_path** is
    provided, **dest_path** is the corresponding path in the output. If
    **source_path** is not provided, **dest_path** is a directory into which
    the source contents are copied. If **dest_path** is not provided, it
    defaults to the effective value of **source_path**, i.e. things are copied
    into the same locations within the output as they were in the source.

 *  **source**: *string* (optional) --
    A symbolic value indicating where to copy from. Possible values are:

     *  `component`: (the default) Copy files from the component directory
     *  `repo_root`: Copy files from the repository root
     *  `temp`: Copy files from this step's temp directory

 *  **source_path**: *string* (optional) --
    The path of the file or directory to copy from the source. Only this item
    (recursively, if a directory) is copied. If this key is not provided, *all*
    contents of the source are copied (e.g. the default is effectively "`.`")

#### Build step types

This is a list of the available build step types, including their behavior and
any additional configuration keys supported by each.

 *  **build_gem** -- A step that builds a gem package.

    This step builds the gem described by the properly named gemspec file for
    this component. The built package file is copied to this step's output.
    Other steps (such as **release_gem**) can declare it as an input to get
    access to the built package. This step does not run unless it is declared
    as an input dependency, or unless it is requested explicitly using the
    **run** configuration.

 *  **build_yard** -- A step that builds Yardocs.

    This step builds documentation using [YARD](https://yardoc.org). The built
    documentation is copied to this step's output in the directory `doc/`.
    Other steps (such as **push_gh_pages**) can declare it as an input to get
    access to the built documentation. This step does not run unless it is
    declared as an input dependency, or unless it is requested explicitly using
    the **run** configuration.

    This step supports the following additional optional configuration keys.

     *  **bundle_step**: *string* (optional) --
        The name of the bundle step. Defaults to `bundle`. This is used if the
        **uses_gems** key is *not* provided.

     *  **uses_gems**: *array of (string or array of string)* (optional) --
        An array of gem specifications, each of which can be a simple gem name
        or an array including rubygems-style version requirements. These gems
        are provided to Yard, and can include gems such as `redcarpet` that may
        be needed for markup handling. If this key is included, the specified
        gems are installed directly; if not, the bundle step is declared as a
        dependency instead.

 *  **bundle** -- A step that installs the bundle in the component directory.

    This step copies the resulting `Gemfile.lock` to its output. Other steps
    can declare it as an input to get access to the `Gemfile.lock`. This step
    does not run unless it is declared as an input dependency, or unless it is
    requested explicitly using the **run** configuration.

    This step supports the following additional optional configuration keys.

     *  **chdir**: *string* (optional) --
        Change to the specified directory (relative to the component directory)
        when installing the bundle. Defaults to component directory.

 *  **command** -- A step that runs a command in the component directory.

    This step supports the following additional configuration keys. Note that
    the **command** key is required. The others are optional.

     *  **chdir**: *string* (optional) --
        Change to the specified directory (relative to the component directory)
        when running the command. Defaults to component directory.

     *  **command**: *array of string* (required) --
        The command to run

     *  **continue_on_error**: *boolean* (optional) --
        If *true*, continue to run the pipeline if the command exits
        abnormally. If *false* (the default), the pipeline aborts.

    This step does not run unless it is requested explicitly using the **run**
    configuration, or it is declared as a dependency.

 *  **noop** -- A no-op step that does nothing. This type is usually configured
    with inputs and outputs and is used to collect or consolidate data from
    other steps.

    This step does not run unless it is requested explicitly using the **run**
    configuration, or it is declared as a dependency.

 *  **push_gh_pages** -- A step that pushes documentation to the gh-pages branch.

    The documentation to publish should be under `doc/` in the output directory
    of a "source" step, normally the **build_yard** step. This source step is
    automatically declared as a dependency.

    This step supports the following additional optional configuration keys.

     *  **source**: *string* (optional) --
        The name of the source step. Defaults to `build_yard`.

    This step runs if gh-pages publishing is enabled for the component.

 *  **release_gem** -- A step that pushes a gem package to rubygems.org.

    The package must be provided under `pkg/` in the output directory of a
    "source" step, normally the **build_gem** step. This source step is
    automatically declared as a dependency.

    This step supports the following additional optional configuration keys.

     *  **source**: *string* (optional) --
        The name of the source step. Defaults to `build_gem`.

    This step runs if a correctly-named gemspec file is present in the component
    directory.

 *  **release_github** -- A step that creates a git tag and GitHub release.

    This step always runs if present in the pipeline.

 *  **tool** -- A step that runs a Toys tool in the component directory.

    This step supports the following additional configuration keys. Note that
    the **tool** key is required. The others are optional.

     *  **chdir**: *string* (optional) --
        Change to the specified directory (relative to the component directory)
        when running the tool. Defaults to component directory.

     *  **continue_on_error**: *boolean* (optional) --
        If *true*, continue to run the pipeline if the tool exits abnormally.
        If *false* (the default), the pipeline aborts.

     *  **tool**: *array of string* (required) --
        The tool to run

    This step does not run unless it is requested explicitly using the **run**
    configuration, or it is declared as a dependency.

#### Build step modification

A build step modification is a dictionary that modifies one or more existing
steps in the build pipeline. Its format is a dictionary with the keys described
below.

The **name** and **type** fields filter the steps to modify. If neither is
provided, *all* steps are modified.

 *  **name**: *string* (optional) --
    Modify only the step with this unique name.

 *  **type**: *string* (optional) --
    Modify only steps matching this type.

All other keys represent changes to the configuration of matching steps. You
can provide either the *null* value to delete the key, or a new full value for
the key. See [build step configuration](#build-step-configuration) and
[build step types](#build-step-types) for details on the available keys and
their formats.
