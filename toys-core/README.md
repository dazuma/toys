# Toys

Toys is a configurable command line tool. Write commands in config files using
a simple DSL, and Toys will provide the command line binary and take care of
all the details such as argument parsing, online help, and error reporting.
Toys-Core is the command line tool framework underlying Toys. It can be used
to create your own command line binaries using the internal Toys APIs.

For more detailed information about Toys-Core, see the
[Toys-Core User's Guide](https://www.rubydoc.info/gems/toys-core/file/docs/guide.md).
For background information about Toys itself, see the
[Toys User Guide](https://www.rubydoc.info/gems/toys/file/docs/guide.md).

## Quick Start

Here's a ten-minute tutorial to get a feel for how to write a basic command
line binary using Toys-Core.

### Install Toys

Install the **toys-core** gem using:

    gem install toys-core

You may also install the **toys** gem, which brings in **toys-core** as a
dependency.

### Create a Toys File

A *Toys File* is a configuration file used by Toys to define commands, called
"tools" in Toys lingo. If you've used the **toys** binary itself, you've
probably written one already. You use the same file format when you create your
own command line binary using Toys-Core.

Create a new empty directory. In the directory, using your favorite text
editor, create a file called `tools.rb`. Copy the following into the file, and
save it:

    tool "greet" do
      desc "My first tool!"
      flag :whom, default: "world"
      def run
        puts "Hello, #{whom}!"
      end
    end

If you're already familiar with writing Toys Files, feel free to modify and
experiment with it.

### Create Your Binary

Now we will write a command line binary that uses that Toys File. In the same
new directory, create a new file called `mycmd`. Copy the following into it:

    #!/usr/bin/env ruby
    require "toys-core"
    cli = Toys::CLI.new
    cli.add_config_path(File.join(__dir__, "tools.rb"))
    exit(cli.run(ARGV))

Save the file and make it executable:

    chmod +x mycmd

Now you can run your command. Try these, to get a feel for how it behaves by
default:

    ./mycmd greet
    ./mycmd greet --whom=Ruby
    ./mycmd greet --help
    ./mycmd
    ./mycmd foo

### Next Steps

A basic command line binary based on Toys-Core consists of just the binary
itself, and a Toys File (or directory) defining the commands to run. All the
features of Toys, described in the
[Toys User Guide](https://www.rubydoc.info/gems/toys/file/docs/guide.md),
are at your disposal for writing tools for your binary. Or, if you want your
binary to have a single function rather than support a set of tools, you can
just write a toplevel tool in your Toys File.

You'll notice that Toys-Core provides a number of features "out of the box",
such as online help, verbose and quiet flags, and default descriptions. These
features are controlled by Toys *Middleware*, which are classes that customize
the base behavior of Toys-Core. Toys-Core defaults to a certain set of
middleware, but you can customize and change them for your own binary.

Finally, you may want to distribute your binary in a gem. Just make sure you
include the Toys File or Directory in the gem, and that your binary configures
`Toys::CLI` with the correct config path. The Toys File does not need to be in
the require path (i.e. in the `lib` directory), and indeed it is probably best
for it not to be, to prevent users of your gem from requiring it accidentally.

See the
[Toys-Core User's Guide](https://www.rubydoc.info/gems/toys-core/file/docs/guide.md)
for thorough documentation on writing a command line binary using Toys-Core.

## License

Copyright 2018 Daniel Azuma

This software is licensed under the 3-clause BSD license.

See the LICENSE.md file for more information.

The source can be found on Github at https://github.com/dazuma/toys
