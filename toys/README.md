# Toys

Toys is a command line binary that lets you build your own personal suite of
command line tools (with commands and subcommands) using a Ruby DSL. Toys
handles argument parsing, error reporting, logging, help text, and many other
details for you.

You can define commands globally, or scope commands to particular directories
by creating "dot-toys" files in those directories. For example, you might
create a global command to refresh your credentials, and write local commands
to run builds and tests in your project directories.

Toys is designed for software developers, IT specialists, and other power
users who want to write and organized scripts to automate their workflows.

## Quick Start

Here's a five-minute tutorial to get the feel of what Toys can do.

### Install toys

Install the **toys** gem using:

    gem install toys

This installs the `toys` binary, along with some builtin tools and libraries.
You can run toys immediately:

    toys

This displays help for the toys tool. You'll notice it also lists some tools
that are preinstalled. Let's run one of them:

    toys system version

The "system version" tool just displays the current version of the toys gem.

### Write your first tool

You can define tools by creating toys *config files*. Using your favorite
editor, create a new file called `.toys.rb` (note the leading period) in your
current directory. Copy the following into the file, and save it:

    tool "greet" do
      desc "My first tool!"
      flag :whom, default: "world"
      execute do
        puts "Hello, #{options[:whom]}!"
      end
    end

This defines a tool called "greet". Try running it:

    toys greet

The tool we created here recognizes a flag on the command line. Try using it:

    toys greet --whom=ruby

Toys provides a rich set of features for defining command line arguments and
flags. It can also validate arguments. Try this:

    toys greet --hello

Notice that Toys automatically generated a usage summary for your tool. It can
also automatically generate a full help screen, which you can invoke using the
`--help` flag:

    toys greet --help

### Next steps

You can add any number of additional tools to your `.toys.rb` file. Note also
that the tools you created in that file are available only in this directory
and its subdirectories; if you move outside the directory tree, they are no
longer present. You can use this to create tools scoped to particular
directories and projects.

Toys also lets you create hierarchies of tools. The "system version" tool you
tried earlier is an example. The "system" tool is a "group". It's a namespace
for tools, and various tools are available under that namespace.

Toys provides a rich set of useful libraries for writing tools. It gives you a
logger and automatically provides flags to control verbosity of log output. It
includes the Highline library, which you can use to produce styled output,
console-based interfaces, and special effects. It also includes a library that
makes it easy to control subprocesses.

For a more detailed look at Toys, see the extended tutorial and user's guide.

Most of the functionality of Toys is implemented in the **toys-core** gem.
This gem provides interfaces that gem writers can use to create their own
command line tools based on the Toys feature set. For more info on using
toys-core, see
[https://ruby-doc.info/gems/toys-core](https://ruby-doc.info/gems/toys-core).

## Contributing

While we appreciate contributions, please note that this software is currently
highly experimental, and the code is evolving very rapidly. Please contact the
author before embarking on a major pull request. More detailed contribution
guidelines will be provided when the software stabilizes further.

The source can be found on Github at
[https://github.com/dazuma/toys](https://github.com/dazuma/toys)

## License

Copyright 2018 Daniel Azuma

This software is licensed under the 3-clause BSD license.

See the LICENSE.md file for more information.
