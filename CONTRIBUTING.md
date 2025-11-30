# How to contribute to Toys

Thank you for your interest in contributing to Toys!

Toys is open source, MIT-licensed. Community contributions are welcome. The
Toys source is hosted on GitHub at
[https://github.com/dazuma/toys](https://github.com/dazuma/toys), and
development is done in the open via commits and pull requests.

## Bug reports

Bugs can be reported on the issue tracker at
[https://github.com/dazuma/toys/issues](https://github.com/dazuma/toys/issues).
When you file a bug, please include detailed instructions for reproducing the
issue, including your `.toys.rb` tool definition if applicable, and describe
both the expected behavior and the actual behavior. Please also include the
version of Toys and the version of Ruby you are running.

Before filing a bug, please search the existing issues to make sure your report
isn't a duplicate. If you do find an existing report, feel free to add a
comment providing any additional information you have.

However, do not add comments to an _already-closed_ issue, even if it looks
like the same or similar issue. Instead, open a new issue, and reference the
closed issue if it looks like it could be related. (We're not saying this to be
difficult or pedantic. GitHub makes it difficult to see changes made to closed
issues, so your message will simply be more visible if you open a new issue.)

## Code contributions

Patches are welcome. Feel free to open a pull request on GitHub at
[https://github.com/dazuma/toys/pulls](https://github.com/dazuma/toys/pulls),
and a maintainer will get in touch with you. When considering pull requests,
please keep the following in mind:

 *  We might not accept features that don't match the maintainers' vision for
    the project. If you're fixing an existing issue, there's a good chance your
    code will be accepted, but if you'd like to add a feature, we strongly
    recommend that you open an issue first, explaining the feature and how it
    fits into the tool, and get agreement from the maintainers before actually
    writing code. In general, the maintainers reserve the right to refuse any
    code contribution, with or without a stated reason.
 *  All new and changed functionality must include tests. Toys uses Minitest
    "spec" style tests, but with assertions instead of expectations. See the
    existing tests for examples of how to format your tests.
 *  All pull requests must pass CI, which includes tests, RuboCop, and
    documentation coverage. You can run CI locally using `toys ci`.
 *  By contributing code, you agree that your modifications will be covered
    under the Toys copyright notice and MIT license. If you require credit for
    yourself or your organization, you may request to be added to an AUTHORS
    file.
