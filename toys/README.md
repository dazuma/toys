# Toys

Toys is a configurable command line tool. Write commands in Ruby using a simple
DSL, and Toys will provide the command line executable and take care of all the
details such as argument parsing, online help, and error reporting.

Toys is designed for software developers, IT professionals, and other power
users who want to write and organize scripts to automate their workflows. It
can also be used as a replacement for Rake, providing a more natural command
line interface for your project's build tasks.

Unlike most command line frameworks, Toys is *not primarily* designed to help
you build and ship a custom command line executable written in Ruby. However,
you *can* use it in that way with the "toys-core" API, available as a separate
gem. For more info on using toys-core, see
[its documentation](https://dazuma.github.io/toys/gems/toys-core/latest).

## Introductory tutorial

Here's a tutorial to help you get a feel of what Toys can do.

### Install Toys

Install the **toys** gem using:

    $ gem install toys

This installs the `toys` executable, along with some builtin tools and
libraries. You can run the executable immediately:

    $ toys

This displays overall help for Toys. If you have `less` installed, Toys will
use it to display the help screen. Press `q` to exit.

You may notice that the help screen lists some tools that are preinstalled.
Let's run one of them:

    $ toys system version

The `system version` tool displays the current version of the toys gem.

Toys also provides optional tab completion for bash. To install it, execute the
following command in your shell, or add it to your bash configuration file
(e.g. `~/.bashrc`).

    $(toys system bash-completion install)

Toys does not yet specially implement tab completion for zsh or other shells.
However, if you are using zsh, installing bash completion using `bashcompinit`
*mostly* works.

Toys requires Ruby 2.4 or later.

Most parts of Toys work on JRuby. However, JRuby is not recommended because of
JVM boot latency, lack of support for Kernel#fork, and other issues.

### Write your first tool

You can define tools by creating a *Toys file*. Go into any directory, and,
using your favorite editor, create a new file called `.toys.rb` (note the
leading period). Copy the following text into the file, and save it:

    tool "greet" do
      desc "My first tool!"
      flag :whom, default: "world"
      def run
        puts "Hello, #{whom}!"
      end
    end

This defines a tool named "greet". Try running it:

    $ toys greet

The tool also recognizes a flag on the command line. Try this:

    $ toys greet --whom=ruby

Toys provides a rich set of features for defining command line arguments and
flags. It can also validate arguments. Try this:

    $ toys greet --bye

Notice that Toys automatically generated a usage summary for your tool. It also
automatically generates a full help screen, which you can view using the
`--help` flag:

    $ toys greet --help

Toys searches up the directory hierarchy for Toys files. So it will find this
`.toys.rb` if you are located in this directory or any subdirectory. It will
also read multiple files if it finds them, so you can "scope" your tools more
specifically or generally by locating them in your directory hierarchy.

If you want to define "global" tools that apply anywhere, write a Toys file
either in your home directory, or in the system configuration directory
(usually `/etc`). Toys always searches these locations.

### A more sophisticated example

Let's take a look at another example that exercises some of the features you're
likely to see in real-world usage. Add the following to your `.toys.rb` file.
(You don't need to replace the greet tool you just wrote; just add this new
tool to the end of the file.)

    tool "new-repo" do
      desc "Create a new git repo"

      optional_arg :name, desc: "Name of the directory to create"

      include :exec, exit_on_nonzero_status: true
      include :fileutils
      include :terminal

      def run
        if name.nil?
          response = ask "Please enter a directory name: "
          set :name, response
        end
        if File.exist? name
          puts "Aborting because #{name} already exists", :red, :bold
          exit 1
        end
        logger.info "Creating new repo in directory #{name}..."
        mkdir name
        cd name do
          create_repo
        end
        puts "Created repo in #{name}", :green, :bold
      end

      def create_repo
        exec "git init"
        File.write ".gitignore", <<~CONTENT
          tmp
          .DS_STORE
        CONTENT
        # You can add additional files here.
        exec "git add ."
        exec "git commit -m 'Initial commit'"
      end
    end

Now you should have an additional tool called `new-repo` available. Type:

    $ toys

The help screen lists both the `greet` tool we started with, and the new
`new-repo` tool. This new tool creates a directory containing a newly created
git repo. (It assumes you have `git` available on your path.) Try running it:

    $ toys new-repo foo

That should create a directory `foo`, initialize a git repository within it,
and make a commit.

Notice that this tool accepts a positional command line argument. Toys supports
any combination of flags and required and optional arguments. This tool's
argument is declared with a description string, which you can see if you view
the tool's help:

    $ toys new-repo --help

The argument is marked as "optional" which means you can omit it. Notice that
the tool's code detects that it has been omitted and responds by prompting you
interactively for a directory name. You can also mark a positional argument as
"required", which causes Toys to report a usage error if it is omitted.

Next, notice this tool includes two methods, `create_repo` as well as `run`.
The "entrypoint" for a tool is always the `run` method, but each tool is
actually a class under the hood, and you can add any helper methods you want.
You can even define and include modules if you want to share code across tools.

For our tool, notice that the three "include" lines are taking symbols rather
than modules. These symbols are the names of some of Toys's built-in helper
*mixins*, which are configurable modules that enhance your tool. They may
provide methods your tool can call, or invoke other behavior. In our example:

*   The `:exec` mixin provides a variety of methods for running external
    commands. In this example, we use the `exec` method to run shell
    commands, but you can also signal and control these commands, capture
    and redirect streams, and so forth. Note that we pass the
    `:exit_on_nonzero_status` option, which configures the `:exec` mixin to
    abort the tool automatically if any of the external commands fails (similar
    to `set -e` in bash). This is a common pattern when writing tools that
    invoke external commands. (If you want more control, the `:exec` mixin also
    provides ways to respond to result codes individually.)
*   The `:fileutils` mixin provides the methods of the Ruby `FileUtils`
    library, such as `mkdir` and `cd` used in this example. It's effectively
    shorthand for `require "fileutils"; include ::FileUtils`.
*   The `:terminal` mixin provides styled output, as you can see with the style
    codes being passed to `puts`. It also provides some user interaction
    commands such as `ask`, as well as spinners and other controls. You can see
    operation of the `:terminal` mixin in the tool's output, which is styled
    either green (for success) or red (on error) when running on a supported
    tty.

Now try running this:

    $ toys new-repo bar --verbose

You'll notice some diagnostic log output. Toys provides a standard Ruby Logger
for each tool, and you can use it to emit diagnostic logs directly as
demonstrated in the example. Some other Toys features might also emit log
entries: the `:exec` mixin, for example, by default logs every external command
it runs (although this can be customized).

By default, only warnings and higher severity logs are displayed, but you can
change that by applying the `--verbose` or `--quiet` flags as we have done
here. These flags, like `--help`, are provided automatically to every tool.

### A better Rake?

Let's look at one more example. Traditionally, Ruby developers often use
Rakefiles to write scripts for tasks such as build, test, and deploy. And Toys
is similar to Rake in how it uses directory-scoped files to define tools.

But Rake is really designed for dependency management, not for writing scripts.
As a result, some features, such as passing arguments to a task, are very
clumsy with Rake.

If you have a project with a Rakefile, move into that directory and create a
new file called `.toys.rb` in that same directory (next to the Rakefile). Add
the following line to your `.toys.rb` file:

    expand :rake

This syntax is called a "template expansion." It's a way to generate tools
programmatically. In this case, Toys provides the `:rake` template, which reads
your Rakefile and generates Toys tools corresponding to all your Rake tasks!
Now if you run:

    $ toys

You'll see that you now have tools associated with each of your Rake tasks. So
if you have a `rake test` task, you can run it using `toys test`.

Note that if you normally run Rake with Bundler (e.g. `bundle exec rake test`),
you may need to add Toys to your Gemfile and use Bundler to invoke Toys (i.e.
`bundle exec toys test`). This is because Toys is just calling the Rake API to
run your task, and the Rake task might require the bundle. However, when Toys
is not wrapping Rake, typical practice is actually *not* to use `bundle exec`.
Toys provides its own mechanisms to setup a bundle, or to activate and even
install individual gems.

So far, we've made Toys a front-end for your Rake tasks. This may be useful by
itself. Toys lets you pass command line arguments "normally" to tools, whereas
Rake requires a weird square bracket syntax (which may also require escaping
depending on your shell.) Toys also provides more sophisticated online help
than Rake does.

But you also might find Toys a more natural way to *write* tasks, and indeed
you can often rewrite an entire Rakefile as a Toys file and get quite a bit of
benefit in readability and maintainability. For an example, see the
[Toys file for the Toys repo itself](https://github.com/dazuma/toys/blob/main/toys/.toys.rb).
It contains the Toys scripts that I use to develop, test, and release Toys
itself. Yes, Toys is self-hosted. You'll notice most of this Toys file consists
of template expansions. Toys provides templates for a lot of common build,
test, and release tasks for Ruby projects.

If you're feeling adventurous, try translating some of your Rake tasks into
native Toys tools. You can do so in your existing `.toys.rb` file. Keep the
`expand :rake` line at the *end* of the file, and locate your tools (whether
simple tools or template expansions) before it. That way, your Toys-native
tools will take precedence, and `expand :rake` will proxy out to Rake only for
the remaining tasks that haven't been ported explicitly.

### Learning more

This introduction should be enough to get you started. However, Toys is a deep
tool with many more features, all explained in detail in the
[User Guide](https://dazuma.github.io/toys/gems/toys/latest/file.guide.html).

For example, Toys lets you create tool namespaces and "subtools", and search
for tools by name and description. There are various ways to validate and
interpret command line arguments. You can create your own mixins and templates,
and take advantage of a variety of third-party libraries such as Highline and
TTY. Finally, if your `.toys.rb` files are growing too large or complicated,
you can replace them with `.toys` directories that contain tool definitions in
separate files. Such directories are versatile, letting you organize your tool
definitions, along with shared code, normal Ruby classes, and even data files
for use by tools.

Unlike most command line frameworks, Toys is *not primarily* designed to help
you build and ship a custom command line executable written in Ruby. However,
you *can* use it in that way with the "toys-core" API, available as a separate
gem. You would effectively write your command line executable using the same
Toys DSL that you use to write `.toys.rb` files. For more info on using
toys-core, see
[its documentation](https://dazuma.github.io/toys/gems/toys-core/latest).

## Why Toys?

I originally wrote Toys because I was accumulating dozens of *ad hoc* Ruby
scripts I had written to automate various tasks in my workflow, everything from
refreshing credentials, to displaying git history in my favorite format, to
running builds and tests of complex multi-component projects. It was becoming
difficult to remember which scripts did what, and what arguments each required,
and I was constantly digging back into their source just to remember how to use
them. Furthermore, when writing new scripts, I was repeating the same
OptionParser boilerplate and common functionality.

Toys was designed to address those problems by providing a framework for
writing *and organizing* your own command line scripts. You provide the actual
functionality by writing Toys files, and Toys takes care of all the other
details expected from a good command line tool. It provides a streamlined
interface for defining and handling command line flags and positional
arguments, and sensible ways to organize shared code. It automatically
generates help text so you can see usage information at a glance, provides a
search feature to help you find the script you need, and generates tab
completion for your shell.

Toys can also be used to share scripts. For example, it can be used instead of
Rake to provide build and test scripts for a project. Unlike Rake tasks,
scripts written for Toys can be invoked and passed arguments and flags using
familiar unix command line conventions. The Toys github repo itself comes with
Toys scripts instead of Rakefiles.

## License

Copyright 2019-2020 Daniel Azuma and the Toys contributors

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
