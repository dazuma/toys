# Toys-CI

Toys-CI is a framework for generating CI Toys tools.

## Description

Continuous Integration (CI) in a project typically involves running a variety
of jobs, such as dependency installation, code linting, unit testing, build
verification, and so forth. A large code base, or a monorepo that includes a
number of smaller components, may require a large number of these jobs. Often
it is desirable to have a "coordinator" job that decides which CI jobs to run
in what order, and collects and summarizes their results.

Toys-CI is a framework for generating simple CI coordinator tools. It provides
a declarative interface for configuring the tool and specifying individual jobs
to run. The generated tool runs jobs specified using command line arguments,
and produces a final report of the results.

### Basic example

Given the following `.toys.rb`:

```ruby
# Create a "test" tool that runs minitest-based tests
expand :minitest, bundler: true

# Create a "rubocop" tool that checks the code base
expand :rubocop, bundler: true

# Create a "ci" tool that runs the above tools and
# summarizes their results
tool "ci" do
  load_gem "toys-ci"

  expand(Toys::CI::Template) do |ci|
    ci.only_flag = true
    ci.tool_job("Run Rubocop", ["rubocop"], flag: :rubocop)
    ci.tool_job("Run tests", ["test"], flag: :tests)
  end
end
```

Now you can:

```
$ toys ci                 # Runs both jobs
$ toys ci --only --tests  # Runs only the tests
```

### Key features

 *  Two interfaces: a high level Template interface that generates an entire
    tool for you including configuration flags, and a low-level Mixin interface
    that provides convenient methods that you can call to write your own CI
    tool.

 *  The high-level interface generates flags that allow selection of individual
    jobs and groups of jobs to execute.

 *  Optionally analyzes diffs and skips jobs that do not need executing because
    no relevant changes have occurred.

 *  Customize your tool, including implementing additional flags and
    functionality, using the power of the Toys framework.

### System requirements

Toys-CI requires Ruby 2.7 or later, and Toys 0.20 or later. We recommend the
latest version of Ruby, JRuby, or TruffleRuby. The Ruby provided by the
standard `setup-ruby` GitHub Action is sufficient.

### Learning more

For more information on the underlying Toys framework, see the
[Toys README](https://dazuma.github.io/toys/gems/toys/latest) and the
[Toys User Guide](https://dazuma.github.io/toys/gems/toys/latest/file.guide.html).

## License

Copyright 2026 Daniel Azuma and the Toys contributors

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
