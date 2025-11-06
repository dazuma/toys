# Toys-Release

Toys-Release is a library release system built on GitHub Actions and the Toys
gem. It uses [conventional commit](https://conventionalcommits.org/) message
format to automate generation of changelogs and library versions, and then lets
you fine tune and approve releases using GitHub pull requests. Out of the box,
it knows how to tag GitHub releases, push gems to Rubygems, and build and
publish documentation to gh-pages. You can also customize the build pipeline
and most aspects of its behavior.

Toys-Release is distributed as a set of Toys tools that are designed to be
called from GitHub Actions.

For more detailed information, see the
[User's Guide](https://dazuma.github.io/toys/gems/toys-release/latest/file.guide.html).

## The release experience

(TODO)

## Getting started

(TODO)

## System requirements

Toys-Core requires Ruby 2.7 or later, and Toys 0.17 or later. We recommend the
latest version of the standard C implementation of Ruby. (JRuby or TruffleRuby
_may_ work, but are unsupported and not recommended due to JVM boot latency.)

## License

Copyright 2019-2025 Daniel Azuma and the Toys contributors

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
