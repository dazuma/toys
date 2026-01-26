# Toys-Release

Toys-Release is a Ruby library release system built on GitHub Actions and the
Toys gem. It interprets [conventional commit](https://conventionalcommits.org/)
message format to automate changelog generation and library version updating
based on semantic versioning, and supports fine tuning and approval of releases
using GitHub pull requests.

Out of the box, Toys-Release knows how to tag GitHub releases, build and push
gems to RubyGems, and build and publish documentation to gh-pages. You can also
customize the build pipeline and many aspects of its behavior.

## Description

Toys-Release is desigend to be installed on a GitHub repository. This
installation consists of a set of GitHub Actions workflows, a configuration
file, and a GitHub Actions secret for your RubyGems credentials.

Once installed, Toys-Release provides command line tools and GitHub Actions
workflows for performing and managing releases. These tools are built atop the
Toys framework.

### The Toys release process

Releases using Toys-Release will generally look like the following.

When you are ready to do a release, go to the GitHub Action tab on your
repository and trigger the "Open Release Request" action. (Alternately, you can
run this action on the command line.) This action analyzes your repository,
finding changes that were committed since the last release. If those commit
messages were formatted properly with Conventional Commit tags, the action will
be able to generate a new entry in your changelog, and suggeset a proper
version for the new release in line with Semantic Versioning. It will then open
a pull request with the version update and changelog addition.

You can then review this pull request and modify it if you want to alter the
version to be released, or the changelog text. Once you are satisfied, merge
the pull request. Toys-Release will then automatically perform the release,
tagging it in GitHub and building and pushing a new Ruby gem release. It can
also be configured to build your gem's documentation and push it to your
repository's gh-pages branch for publication. You can cancel the release simply
by closing the pull request without merging.

### Key features

* Tight integration with GitHub Actions provides a convenient workflow for
  GitHub-based projects.
* Automatically generates changelogs based on Conventional Commit messages.
* Automatically proposes releases with semver-aligned version increments based
  on the semantics implied by the commit messages.
* Approve and adjust releases and changelogs by editing pull requests.
* Automatic pre-release checks verify that CI passes and release status is
  consistent.
* Fix and retry failed releases via GitHub Actions or command line.
* Supports single-library repositories and multi-library monorepos.
* Support for groups of libraries that must be released together.
* Support for publishing reference documentation to gh-pages.
* Fine-grained configuration of the release pipeline.

### System requirements

Toys-Release requires Ruby 2.7 or later, and Toys 0.18 or later. We recommend
the latest version of the standard C implementation of Ruby. (JRuby or
TruffleRuby _may_ work, but are unsupported.) The Ruby provided by the standard
`setup-ruby` GitHub Action is sufficient.

### Learning more

Detailed setup, usage, and reference documentation can be found in the
[Toys-Release User Guide](https://dazuma.github.io/toys/gems/toys-release/latest/file.guide.html).

For more information on the underlying Toys framework, see the
[Toys README](https://dazuma.github.io/toys/gems/toys/latest) and the
[Toys User Guide](https://dazuma.github.io/toys/gems/toys/latest/file.guide.html).

## License

Copyright 2025-2026 Daniel Azuma and the Toys contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
IN THE SOFTWARE.




