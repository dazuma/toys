# Toys

[![Travis-CI Build Status](https://travis-ci.org/dazuma/toys.svg)](https://travis-ci.org/dazuma/toys/)

Toys is a configurable command line tool. Write commands in config files using
a simple DSL, and Toys will provide the command line binary and take care of
all the details such as argument parsing, online help, and error reporting.

Toys is designed for software developers, IT professionals, and other power
users who want to write and organize scripts to automate their workflows. It
can also be used as a Rake replacement, providing a more natural command line
interface for your project's build tasks.

This repository includes the source for two gems:

*   **toys** provides the Toys binary itself and all its capabilities.
*   **toys-core** provides the underlying command line framework, and can be
    used to build other command line binaries.

## Quick Start

Here's a five-minute tutorial to get a feel of what Toys can do.

### Install toys

Install the **toys** gem using:

    gem install toys

This installs the `toys` binary, along with some builtin tools and libraries.
You can run the binary immediately:

    toys

This displays overall help for the Toys binary. If you have `less` installed,
Toys will use it to display the help screen. Press `q` to exit.

You may notice that the help screen lists some tools that are preinstalled.
Let's run one of them:

    toys system version

The "system version" tool displays the current version of the toys gem.

### Write your first tool

You can define tools by creating a *Toys file*. Go into any directory, and,
using your favorite editor, create a new file called `.toys.rb` (note the
leading period). Copy the following into the file, and save it:

    tool "greet" do
      desc "My first tool!"
      flag :whom, default: "world"
      def run
        puts "Hello, #{whom}!"
      end
    end

This defines a tool named "greet". Try running it:

    toys greet

The tool also recognizes a flag on the command line. Try this:

    toys greet --whom=ruby

Toys provides a rich set of features for defining command line arguments and
flags. It can also validate arguments. Try this:

    toys greet --bye

Notice that Toys automatically generated a usage summary for your tool. It also
automatically generates a full help screen, which you can view using the
`--help` flag:

    toys greet --help

### Next steps

You can add any number of additional tools to your `.toys.rb` config file. Note
also that the tools you create in the config file are available only in this
directory and its subdirectories. If you move into a different directory tree,
Toys will instead look for a config file in that directory. Thus, you can
define tools scoped to particular projects. You can also define "global" tools
by creating a `.toys.rb` file in your home directory.

Toys provides a rich set of useful libraries for writing tools and subtools. It
gives you a logger and automatically provides flags to control verbosity of log
output. It includes a simple library that you can use to produce styled output
and basic console-based interfaces, and another library that makes it easy to
spawn and control subprocesses. You can also take advantage of a variety of
third-party libraries such as Highline and TTY.

For a more detailed look at Toys, see the
[User Guide](https://www.rubydoc.info/gems/toys/file/docs/guide.md).

Unlike most command line frameworks, Toys is *not primarily* designed to help
you build and ship a custom command line binary written in Ruby. However, you
*can* use it in that way by building with the "toys-core" API, available as a
separate gem. For more info on using toys-core, see
https://www.rubydoc.info/gems/toys-core

## Why Toys?

I wrote Toys because I was accumulating dozens of ad hoc Ruby scripts that I
had written to automate various tasks in my workflow, everything from
refreshing credentials, to displaying git history in my favorite format, to
running builds and tests of complex multi-component projects. It was becoming
difficult to remember which scripts did what, and what arguments each required,
and I was constantly digging back into their source just to remember how to use
them. Furthermore, when writing new scripts, I was repeating the same
OptionParser boilerplate and common functionality.

Toys was designed to address those problems by providing a framework for
writing and organizing your own command line scripts. You provide the actual
functionality, and Toys takes care of all the other details expected from a
good command line tool. It provides a streamlined interface for defining and
handling command line flags and positional arguments, and sensible ways to
organize shared code. It automatically generates help text, so you can see
usage information at a glance, and it also provides a search feature to help
you find the script you need.

Toys can also be used to share scripts. For example, it can be used instead of
Rake to provide build and test scripts for a project—tools that, unlike Rake
tasks, can be invoked and passed arguments and flags using familiar unix
command line conventions. The Toys github repo itself comes with Toys config
files instead of Rakefiles.

## License

Copyright 2018 Daniel Azuma

This software is licensed under the 3-clause BSD license.

See the LICENSE.md file for more information.

The source can be found on Github at https://github.com/dazuma/toys
