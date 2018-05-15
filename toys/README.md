# Toys

Toys is a command line binary that lets you build your own personal suite of
command line tools using a Ruby DSL. Toys handles argument parsing, error
reporting, logging, help text, and many other details for you. Toys is designed
for software developers, IT specialists, and other power users who want to
write and organize scripts to automate their workflows.

I wrote Toys because I was accumulating dozens of ad hoc Ruby scripts that I
had written to automate everything from refreshing credentials, to displaying
git history in my favorite format, to running builds and tests of complex
multi-component projects. It was becoming difficult to remember which scripts
did what, and what arguments to pass, and I was repeating the same
OptionParser and common tool boilerplate each time I wrote a new one.

Toys is a powerful tool that makes it easy to write and organize your scripts.
You write your functionality, and Toys takes care of all the details expected
from a good command line tool.

You can also use the core functionality of Toys to create your own command line
binaries, by using the *toys-core* API, which is available as a separate gem.
For more info on using toys-core, see
[https://ruby-doc.info/gems/toys-core](https://ruby-doc.info/gems/toys-core).

## Quick Start

Here's a five-minute tutorial to get the feel of what Toys can do.

### Install toys

Install the **toys** gem using:

    gem install toys

This installs the `toys` binary, along with some builtin tools and libraries.
You can run the binary immediately:

    toys

This displays overall help for the Toys binary. If you have `less` installed,
Toys will use it to display the help screen. Press `q` to exit.

You may notice that the help text lists some tools that are preinstalled. Let's
run one of them:

    toys system version

The "system version" tool displays the current version of the toys gem.

### Write your first tool

You can define tools by creating toys *config files*. Using your favorite
editor, create a new file called `.toys.rb` (note the leading period) in your
current directory. Copy the following into the file, and save it:

    tool "greet" do
      desc "My first tool!"
      flag :whom, default: "world"
      script do
        puts "Hello, #{options[:whom]}!"
      end
    end

This defines a tool named "greet". Try running it:

    toys greet

The tool also recognizes a flag on the command line. Try this:

    toys greet --whom=ruby

Toys provides a rich set of features for defining command line arguments and
flags. It can also validate arguments. Try this:

    toys greet --hello

Notice that Toys automatically generated a usage summary for your tool. It also
automatically generates a full help screen, which you can view using the
`--help` flag:

    toys greet --help

### Next steps

You can add any number of additional tools to your `.toys.rb` file. Note also
that the tools you created in that file are available only in this directory
and its subdirectories; if you move outside the directory tree, they are no
longer present. You can use this to create tools scoped to particular
directories and projects.

Toys also lets you create hierarchies of tools. The "system version" tool you
tried earlier is an example. The "system" tool is treated as a namespace, and
various subtools, such as "version", are available under that namespace.

Toys provides a rich set of useful libraries for writing tools. It gives you a
logger and automatically provides flags to control verbosity of log output. It
includes the Highline library, which you can use to produce styled output,
console-based interfaces, and special effects. It also includes a library that
makes it easy to control subprocesses.

For a more detailed look at Toys, see the
{file:docs/tutorial.md Extended Tutorial} and {file:docs/guide.md User Guide}.

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
