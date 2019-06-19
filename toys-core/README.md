# Toys-Core

Toys is a configurable command line tool. Write commands in config files using
a simple DSL, and Toys will provide the command line executable and take care
of all the details such as argument parsing, online help, and error reporting.

Toys-Core is the command line tool framework underlying Toys. It can be used
to write command line executables using the Toys DSL and the power of the Toys
classes.

For more detailed information about Toys-Core, see the
[Toys-Core User's Guide](https://www.rubydoc.info/gems/toys-core/file/docs/guide.md).
For background information about Toys itself, see the
[Toys README](https://www.rubydoc.info/gems/toys) and the
[Toys User Guide](https://www.rubydoc.info/gems/toys/file/docs/guide.md).

## Introductory tutorial

Here's a tutorial to help you get a feel for how to write a basic command line
executable using Toys-Core.

It assumes basic familiarity with Toys, so, if you have not done so, I
recommend first walking through the tutorial in the
[Toys README](https://www.rubydoc.info/gems/toys). It also assumes you are
running a unix-like system such as Linux or macOS. Some commands might need to
be modified if you're running on Windows.

### Install Toys

Toys requires Ruby 2.3 or later.

Install the **toys-core** gem using:

    $ gem install toys-core

You may also install the **toys** gem, which brings in **toys-core** as a
dependency.

### Create a new executable

We'll start by creating an executable Ruby script. Using your favorite text
editor, create new a file called `mycmd` with the following contents:

    #!/usr/bin/env ruby

    require "toys-core"

    cli = Toys::CLI.new

    exit(cli.run(*ARGV))

Make sure the file's executable bit is set:

    $ chmod a+x mycmd

That's it! This is a fully-functional Toys-based executable! Let's see what
happens when you run it:

    $ ./mycmd

Just as with Toys itself, you get a help screen by default (since we haven't
yet actually implemented any behavior.) As you can see, some of the same
features from Toys are present already: online help, and `--verbose` and
`--quiet` flags. These features can of course all be customized, but they're
useful to have to start off.

### Add some functionality

You implement the functionality of your executable using the same DSL that you
use to write Toys files. You could point your executable at a directory
containing actual Toys files, but the simplest option is to provide the
information to the Toys CLI object in a block.

Let's add some functionality. 

    #!/usr/bin/env ruby

    require "toys-core"

    cli = Toys::CLI.new

    #### Insert the following block ...
    cli.add_config_block do
      desc "My first executable!"
      flag :whom, default: "world"
      def run
        puts "Hello, #{whom}!"
      end
    end

    exit(cli.run(*ARGV))

If you went through the tutorial in the README for the Toys gem, this should
look familiar. Let's run it now, and experiment with passing flags to it.

    $ ./mycmd
    $ ./mycmd --whom=ruby
    $ ./mycmd --bye
    $ ./mycmd --help

Notice that we did not create a `tool` block, but instead set up description,
flags, and functionality directly in the configuration block. This configures
the "root tool", i.e. what happens when you run the executable without passing
a tool name to it. (Note, it's legal to do this in Toys as well, by setting
functionality at the "top level" of a `.toys.rb` file without including any
`tool` block.)

### Tool-based executables

But perhaps you want your executable to have multiple "tools", similar to other
familiar executables like git or kubectl. You can define tools, including
nested tools, by writing `tool` blocks in your config. Here's an example:

    #!/usr/bin/env ruby

    require "toys-core"

    cli = Toys::CLI.new

    #### Change the config block as follows ...
    cli.add_config_block do
      # Things outside any tool block still apply to the root
      desc "My first executable with several tools"

      # We'll put the greet function here
      tool "greet" do
        desc "My first tool!"
        flag :whom, default: "world"
        def run
          puts "Hello, #{whom}!"
        end
      end

      # Try writing a second tool here. You could use the "new-repo"
      # example from the Toys tutorial.
    end

    exit(cli.run(*ARGV))

Now you can run `greet` as a tool:

    $ ./mycmd greet

The "root" functionality once again shows global help, including a list of the
available tools.

    $ ./mycmd

Notice that the description set at the "root" of the config block (outside the
tool blocks) shows up here.     

### Configuring the CLI

So far, our executable behaves very similarly to Toys itself. Help screens are
shown by default, flags for help and verbosity are provided automatically, and
any exceptions are displayed to the terminal.

These and many more aspects of the behavior of our executable can be customized
by passing options to the `Toys::CLI` constructor. Here's an example that
modifies error handling and delimiter parsing.

    #!/usr/bin/env ruby

    require "toys-core"

    #### Pass some additional options to the CLI constructor ...
    cli = Toys::CLI.new(
      extra_delimiters: ":",
      error_handler: ->(e) {
        puts "Dude, an error happened..."
        return 1
      }
    )

    #### Change the config block as follows ...
    cli.add_config_block do
      tool "example" do
        tool "greet" do
          def run
            puts "Hello, world!"
          end
        end
        tool "error" do
          def run
            raise "Whoops!"
          end
        end
      end
    end

    exit(cli.run(*ARGV))

Try these runs. Do they behave as you expected?

    $ ./mycmd example greet
    $ ./mycmd example:greet
    $ ./mycmd example.greet
    $ ./mycmd example error

### Configuring middleware

Toys _middleware_ are objects that provide common functionality for all the
tools in your executable. For example, a middleware adds the `--help` flag to
your tools by default.

The next example modifies the middleware stack to alter this common tool
functionality.

    #!/usr/bin/env ruby

    require "toys-core"

    #### Change the CLI construction again ...
    middlewares = [
      [:set_default_descriptions, default_tool_desc: "Hey look, a tool!"],
      [:show_help, help_flags: true]
    ]
    cli = Toys::CLI.new middleware_stack: middlewares

    #### Use this config block ...
    cli.add_config_block do
      tool "greet" do
        def run
          puts "Hello, world!"
        end
      end
    end

    exit(cli.run(*ARGV))

We've now modified the default description applied to tools that don't provide
their own description. See the effect with:

    $ ./mycmd greet --help

We've also omitted some of the default middleware, including the one that adds
the `--verbose` and `--quiet` flags to all your tools. Notice those flags are
no longer present.

We've also omitted the middleware that provides default execution behavior
(i.e. displaying the help screen) when there is no `run` method. Now, since we
haven't defined a toplevel `run` method in this last example, invoking the root
tool will cause an error:

    $ ./mycmd

It is even possible to write your own middleware. In general, while the
`Toys::CLI` constructor provides defaults that should work for many use cases,
you can also customize it heavily to suit the needs of your executable.

### Packaging as a gem

So far we've created simple one-file executables that you could distribute by
itself. However, the `toys-core` gem is a dependency, and your users will need
to have it installed. You could alleviate this by wrapping your executable in a
gem that can declare `toys-core` as a dependency explicitly.

The [examples directory](https://github.com/dazuma/toys/tree/master/toys-core/examples)
includes a few simple examples that you can use as a starting point.

To experiment with the examples, clone the Toys repo from GitHub:

    $ git clone https://github.com/dazuma/toys.git
    $ cd toys

Navigate to the simple-gem example:

    $ cd toys-core/examples/simple-gem

This example wraps the simple "greet" executable that we
[covered earlier](#Add_some_functionality) in a gem. You can see the
[executable file](https://github.com/dazuma/toys/tree/master/toys-core/examples/simple-gem/bin/toys-core-simple-example)
in the bin directory.

Try it out by building and installing the gem. From the `examples/simple-gem`
directory, run:

    $ toys install

Once the gem has successfully installed, you can run the executable, which
Rubygems should have added to your path. (Note: if you are using a ruby
installation manager, you may need to "rehash" or "reshim" to gain access to
the executable.)

    $ toys-core-simple-example --whom=Toys

Clean up by uninstalling the gem:

    $ gem uninstall toys-core-simple-example

If the implementation of your executable is more complex, you might want to
break it up into multiple files. The multi-file gem example demonstrates this.

    $ cd ../multi-file-gem

This executable's implementation resides in its
[lib directory](https://github.com/dazuma/toys/tree/master/toys-core/examples/multi-file-gem/lib),
a technique that may be familiar to writers of command line executables. More
interestingly, the tools themselves are no longer defined in a block passed to
the CLI object, but have been moved into a separate
["tools" directory](https://github.com/dazuma/toys/tree/master/toys-core/examples/multi-file-gem/tools).
This directory has the same structure and supports the same features that are
available when writing complex sets of tools in a `.toys` directory. You then
configure the CLI object to look in this directory for its tools definitions,
as you can see in
[the code](https://github.com/dazuma/toys/tree/master/toys-core/examples/multi-file-gem/lib/toys-core-multi-gem-example.rb).

Try it out now. From the `examples/multi-file-gem` directory, run:

    $ toys install

Once the gem has successfully installed, you can run the executable, which
Rubygems should have added to your path. (Note: if you are using a ruby
installation manager, you may need to "rehash" or "reshim" to gain access to
the executable.)

    $ toys-core-multi-file-example greet

Clean up by uninstalling the gem:

    $ gem uninstall toys-core-multi-file-example

### Learning more

This introduction should be enough to get you started. However, Toys-Core is a
deep framework with many more features. Learn about how to write tools using
the Toys DSL, including validating and interpreting command line arguments,
using templates and mixins, controlling subprocesses, and producing nice styled
output, in the
[Toys User Guide](https://www.rubydoc.info/gems/toys/file/docs/guide.md).
Learn more about how to customize and package your own executable, including
handling errors, controlling log output, and providing your own mixins,
templates, and middleware, in the
[Toys-Core User Guide](https://www.rubydoc.info/gems/toys-core/file/docs/guide.md).

## License

Copyright 2019 Daniel Azuma

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
