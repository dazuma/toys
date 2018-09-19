# @title Toys User Guide

# Toys User Guide

Toys is a configurable command line tool. Write commands in config files using
a simple DSL, and Toys will provide the command line binary and take care of
all the details such as argument parsing, online help, and error reporting.

Toys is designed for software developers, IT professionals, and other power
users who want to write and organize scripts to automate their workflows. It
can also be used as a Rake replacement, providing a more natural command line
interface for your project's build tasks.

Unlike most command line frameworks, Toys is *not primarily* designed to help
you build and ship a custom command line binary written in Ruby. Rather, it
provides a single binary called `toys`. You define the commands recognized by
the Toys binary by writing configuration files. (You can, however, build your
own custom command line binary using the related **toys-core** library.)

This user's guide covers everything you need to know to use Toys effectively.

## Conceptual Overview

Toys is a command line *framework*. It provides a binary called `toys` along
with basic functions such as argument parsing and online help. You provide the
actual behavior of the Toys binary by writing **Toys files**.

Toys is a multi-command binary. You may define any number of commands, called
**tools**, which can be invoked by passing the tool name as an argument to the
`toys` binary. Tools are arranged in a hierarchy; you may define **namespaces**
that have **subtools**.

Tools may recognize command line arguments in the form of **flags** and
**positional arguments**. Flags can optionally take **values**, while
positional arguments may be **required** or **optional**.

The configuration of a tool may include **descriptions**, for the tool itself,
and for each command line argument. These descriptions are displayed in the
tool's **online help** screen. Descriptions come in **long** and **short**
forms, which appear in different styles of help.

Toys searches for tools in specifically-named **Toys files** and **Toys
directories**. It searches for these in the current directory, its ancestors,
and in the Toys **search path**.

Toys provides various features to help you write tools. This includes providing
a **logger** for each tool, **mixins** that provide common functions a tool can
call (such as controlling subprocesses and styling output), and **templates**
which are prefabricated tools that you can configure for your needs.

Finally, Toys provides useful **built-in behavior**, including automatically
providing flags to display help screens and set verbosity. It also includes a
built-in namespace of **system tools** that let you inspect and configure the
Toys system itself.

## The Toys Command Line

In this section, you will learn how Toys parses its command line, identifies a
tool to run, and interprets flags and other command line arguments.

The general form of the `toys` command line is:

    toys [TOOL...] [FLAGS...] [ARGS...]

### Tools

The **tool name** consists of all the command line arguments until the first
argument that begins with a hyphen (which is interpreted as a **flag**), until
no tool with that name exists (in which case the argument is treated as the
first **positional argument**), or until there are no more arguments.

For example, in the following command:

         |----TOOL----|
    toys system version

The tool name is `system version`. Notice that the tool name may have multiple
words. Tools are arranged hierarchically. In this case, `system` is a
**namespace** for tools related to the Toys system, and `version` is one of its
**subtools**. It prints the current Toys version.

In the following command:

         |TOOL| |ARG|
    toys system frodo

There is no subtool `frodo` under the `system` namespace, so Toys works
backward until it finds an existing tool. In this case, the `system` namespace
itself does exist, so Toys runs *it* as the tool, and passes it `frodo` as an
argument.

Namespaces such as `system` are themselves tools and can be executed like any
other tool. In the above case, it takes the argument `frodo`, determines it has
no subtool of that name, and prints an error message. More commonly, though,
you might execute a namespace without arguments:

    toys system

This displays the **online help screen** for the `system` namespace, which
includes a list of all its subtools and what they do.

It is also legitimate for the tool name to be empty. This invokes the **root
tool**, the toplevel namespace:

    toys

Like any namespace, invoking the root tool displays its help screen, including
showing the list of all its subtools.

One last example:

    toys frodo

If there is no tool called `frodo` in the toplevel namespace, then once again,
`frodo` is interpreted as an argument to the root tool. The root tool responds
by printing an error message that the `frodo` tool does not exist.

### Flags

**Flags** are generally arguments that begin with a hyphen, and are used to set
options for a tool.

Each tool recognizes a specific set of flags. If you pass an unknown flag to a
tool, the tool will generally display an error message.

Toys follows the typical unix conventions for flags, specifically those covered
by Ruby's OptionParser library. You can provide short (single-character) flags
with a single hyphen, or long flags with a double hyphen. You can also provide
optional **values** for flags. Following are a few examples.

Pass a single short flag (for verbose output).

    toys system -v

Pass multiple long flags (for verbose output and recursive subtool search).

    toys system --verbose --recursive

You can combine short flags. This does the same as the previous example.

    toys system -rv

Pass a value using a long flag. The root tool supports the `--search` flag to
search for tools that have the given keyword.

    toys --search=build
    toys --search build

Pass a value using a short flag.

    toys -s build
    toys -sbuild

If a double hyphen `--` appears by itself in the arguments, it disables flag
parsing from that point. Any further arguments are treated as positional
arguments, even if they begin with hyphens. For example:

         |--FLAG--|   |---ARG---|
    toys --verbose -- --recursive

That will cause `--recursive` to be treated as a positional argument. (In this
case, as we saw earlier, the root tool will respond by printing an error
message that no tool named `--recursive` exists.)

Note that a single hyphen by itself `-` is not considered a flag, nor does it
disable flag parsing. It is treated as a normal positional argument.

#### Standard Flags

For the most part, each tool specifies which flags and arguments it recognizes.
However, Toys adds a few standard flags globally to every tool. (It is possible
for individual tools to override these flags, but most tools should support
them.) These standard flags include:

*   `--help` (also `-?`) which displays the full help screen for the tool.
*   `--usage` which displays a shorter usage screen for the tool.
*   `--verbose` (also `-v`) which increases the verbosity. This affects the
    tool's logging display, increasing the number of log levels shown. This
    flag may be issued multiple times.
*   `--quiet` (also `-q`) which decreases the verbosity. This affects the
    tool's logging display, decreasing the number of log levels shown. This
    flag may also be issued multiple times.

Namespace tools (tools that have subtools but no explicit functionality of
their own) always behave as though `--help` is invoked. (They do recognize the
flag, but it has no additional effect.) Namespaces also support the following
additional flags:

*   `--[no-]recursive` (also `-r`) which displays all subtools recursively,
    instead of only the immediate subtools.
*   `--search=TERM` which displays only subtools whose name or description
    contain the specified search term.

Finally, the root tool also supports:

*   `--version` which displays the current Toys version.

### Positional Arguments

Any arguments not recognized as flags or flag arguments, are interpreted as
**positional arguments**. Positional arguments are recognized in order and may
be required or optional.

Each tool recognizes a specific set of positional arguments. If you do not pass
a value for a required argument, or you pass too many arguments, the tool will
generally display an error message.

For example, the built-in `do` tool runs multiple tools in sequence. It
recognizes any number of positional arguments. Those arguments specify which
tools to run and what arguments to pass to them. If, for example, you had a
`build` tool and a `test` tool, you could run them in sequence with:

            |---ARGS---|
    toys do build , test

The three arguments `build`, `,`, and `test` are positional arguments to the
`do` tool. (The `do` tool uses `,` to delimit the tools that it should run.)

Here is a more complex example illustrating the interaction between flags and
positional arguments. Suppose we want to use `do` to display the help screens
for the root tool and the system tool in sequence. That is, we want to run
`toys --help` and `toys system --help` in sequence. We might start by trying:

            |FLAG| |-ARGS-| |FLAG|
    toys do --help , system --help

However, this simply displays the help for the `do` tool itself, because the
first `--help` is interpreted as a flag for `do`. What we actually want is for
`do` to treat it as a positional argument specifying the first tool to run. So
Let's force `do` to treat all its arguments as positional, by starting with
`--` like so:

               |--------ARGS--------|
    toys do -- --help , system --help

Now `toys do` behaves as we intended.

## Defining Tools

So far we've been experimenting only with the built-in tools provided by Toys.
In this section, you will learn how to define tools by writing a **Toys file**.
We will cover how to write tools, including specifying the functionality of the
tool, the flags and arguments it takes, and how its description appears in the
help screen.

### Basic Toys Syntax

A file named `.toys.rb` (note the leading period) in the current working
directory is called a **Toys file**. It defines tools available in that
directory and its subdirectories.

The format of a Toys file is a Ruby DSL that includes directives, methods, and
nested blocks. The actual DSL is specified in the
[Toys::DSL::Tool class](https://www.rubydoc.info/gems/toys-core/Toys/DSL/Tool).

To create a tool, write a `tool` block, giving the tool a name. Within the
block, use directives to set the properties of the tool, including descriptions
and the flags and arguments recognized by the tool. The actual functionality of
the tool is set by defining a `run` method.

Let's start with an example:

    tool "greet" do
      desc "Print a friendly greeting."
      long_desc "Prints a friendly greeting. You may customize whom to" \
                  " greet, and how friendly it should be.",
                "",
                "Example:",
                ["    toys greet --shout ruby"]

      optional_arg :whom, default: "world", desc: "Whom to greet."
      flag :shout, "-s", "--shout", desc: "Greet loudly."

      def run
        greeting = "Hello, #{whom}!"
        greeting.upcase! if shout
        puts greeting
      end
    end

Its results should be mostly self-evident. But let's unpack a few details.

### Tool Descriptions

Each tool may have a **short description** and/or a **long description**. The
short description is a generally a single string that is displayed with the
tool name, at the top of its help page or in a subtool list. The long
description generally includes multiple strings, which are displayed in
multiple lines in the "description" section of the tool's help page. Long
descriptions may include blank lines to separate paragraphs visually.

By default, each description string/line is word-wrapped when displayed. In the
long description example above, the first line is a bit longer than 80
characters, and may be word-wrapped if displayed on an 80-character terminal.

If you need to control the wrapping behavior, pass an array of strings for that
line. Each array element will be considered a unit for wrapping purposes, and
will not be split. The example command in the long description above
illustrates how to prevent a line from being word-wrapped. This is also a
useful technique for preserving spaces and indentation.

For more details, see the reference documentation for
[Toys::DSL::Tool#desc](https://www.rubydoc.info/gems/toys-core/Toys%2FDSL%2FTool:desc)
and
[Toys::DSL::Tool#long_desc](https://www.rubydoc.info/gems/toys-core/Toys%2FDSL%2FTool:long_desc).

### Positional Arguments

Tools may recognize any number of **positional arguments**. Each argument must
have a name, which is a key that the tool can use to obtain the argument's
value at execution time. Arguments may also have various properties controlling
how values are validated and expressed.

The above example uses the directive
[Toys::DSL::Tool#optional_arg](https://www.rubydoc.info/gems/toys-core/Toys%2FDSL%2FTool:optional_arg)
to declare an **optional argument** named `:whom`. If the argument is provided
on the command line e.g.

    toys greet ruby

Then the option `:whom` is set to the string `"ruby"`. Otherwise, if the
argument is omitted, e.g.

    toys greet

Then the option `:whom` is set to the default value `"world"`.

If the option name is a valid method name, Toys will provide a method that you
can use to retrieve the value. In the above example, we retrieve the value for
the option `:whom` by calling the method `whom`. If the option name cannot be
made into a method, you can retrieve the value by calling
[Toys::Tool#get](https://www.rubydoc.info/gems/toys-core/Toys%2FTool:get).

An argument may also be **required**, which means it must be provided on the
command line; otherwise the tool will report a usage error. You may declare a
required argument using the directive
[Toys::DSL::Tool#required_arg](https://www.rubydoc.info/gems/toys-core/Toys%2FDSL%2FTool:required_arg).

#### Parsing Required and Optional Arguments

When command line arguments are parsed, the required arguments are matched
first, in order, followed by the optional arguments. For example:

    tool "args-demo" do
      optional_arg :arg2
      required_arg :arg1
      # ...

If a user runs

    toys args-demo foo

Then the required argument `:arg1` will be set to `"foo"`, and the optional
argument `:arg2` will not be set (i.e. it will remain `nil`).

If the user runs:

    toys args-demo foo bar

Then `:arg1` is set to `"foo"`, and `:arg2` is set to `"bar"`.

Running the following:

    toys args-demo

Will produce a usage error, because no value is set for the required argument
`:arg1`. Similarly, running:

    toys args-demo foo bar baz

Will also produce an error, since the tool does not define an argument to
match `"baz"`.

Optional arguments may declare a default value to be used if the argument is
not provided on the command line. For example:

    tool "args-demo" do
      required_arg :arg1
      optional_arg :arg2, default: "the-default"
      # ...

Now running the following:

    toys args-demo foo

Will set the required argument to `"foo"` as usual, and the optional argument,
because it is not provided, will default to `"the-default"` instead of `nil`.

#### Remaining Arguments

Normally, unmatched arguments will result in an error message. However, you can
provide an "argument" to match all **remaining** unmatched arguments at the
end, using the directive
[Toys::DSL::Tool#remaining_args](https://www.rubydoc.info/gems/toys-core/Toys%2FDSL%2FTool:remaining_args).
For example:

    tool "args-demo" do
      required_arg :arg1
      optional_arg :arg2
      remaining_args :arg3
      # ...

Now, running:

    toys args-demo foo bar baz bey

Sets the following option data:

    {arg1: "foo", arg2: "bar", arg3: ["baz", "bey"]}

If instead you run:

    toys args-demo foo

This sets the following option data:

    {arg1: "foo", arg2: nil, arg3: []}

Tools can include any number of `required_arg` and `optional_arg` directives,
declaring any number of required and optional arguments, but they can have only
at most one `remaining_args` directive.

#### Descriptions and the Args DSL

Positional arguments may also have short and long descriptions, which are
displayed in online help. Set descriptions via the `desc:` and `long_desc:`
arguments to the argument directive. The `desc:` argument takes a single string
description, while the `long_desc:` argument takes an array of strings. Here is
an example:

    required_arg :arg,
                 desc: "This is a short description for the arg",
                 long_desc: ["Long descriptions may have multiple lines.",
                             "This is the second line."]

See the [above section on Descriptions](#Tool_Descriptions) for more
information on how descriptions are rendered and word wrapped.

Because long descriptions may be unwieldly to write as a hash argument in this
way, Toys provides an alternate syntax for defining arguments using a block.

    required_arg :arg do
      desc "This is a short description for the arg"
      long_desc "Long desc can be set as multiple lines together,",
                "like this second line."
      long_desc "Or you can call long_desc again to add more lines."
    end

For detailed info on configuring an argument using a block, see the
[Toys::DSL::Arg class](https://www.rubydoc.info/gems/toys-core/Toys/DSL/Arg).

#### Argument Acceptors

Finally, positional arguments may use **acceptors** to define how to validate
arguments and convert them to Ruby objects for your tool to consume. By
default, Toys will accept any argument string, and expose it to your tool as a
raw string. However, you may provide an acceptor to change this behavior.

Acceptors are part of the OptionParser interface, and are described under the
[type coercion](http://ruby-doc.org/stdlib/libdoc/optparse/rdoc/OptionParser.html#class-OptionParser-label-Type+Coercion)
section. For example, you can provide the `Integer` class as an acceptor, which
will validate that the argument is a well-formed integer, and convert it to an
integer during parsing:

    tool "acceptor-demo" do
      required_arg :age, accept: Integer
      def run
        puts "Next year I will be #{age + 1}"  # Age is an integer
        ...

If you pass a non-integer for this argument, Toys will report a usage error.

You may use any of the ready-to-use coercion types provided by OptionParser,
including the special types such as
[OptionParser::DecimalInteger](http://ruby-doc.org/stdlib/libdoc/optparse/rdoc/OptionParser.html#DecimalInteger)
and
[OptionParser::OctalInteger](http://ruby-doc.org/stdlib/libdoc/optparse/rdoc/OptionParser.html#OctalInteger).

You may also create **custom acceptors**. See the
[section below on Custom Acceptors](#Custom_Acceptors) for more information.

### Flags

Tools may also recognize **flags** on the command line. In our "greet" example,
we declared a flag named `:shout`:

    flag :shout, "-s", "--shout", desc: "Greet loudly."

Like a positional argument, a flag sets an option based on the command line
arguments passed to the tool. In the case above, the `:shout` option is set to
`true` if either `-s` or `--shout` is provided on the command line; otherwise
it remains falsy. The two flags `-s` and `--shout` are effectively synonyms and
have the same effect. A flag declaration may include any number of synonyms.

As with arguments, Toys will provide a method that you can call to retrieve the
option value set by a flag. In this case, a method called `shout` will be
available, and will return either true or false. If the option name cannot be
made into a method, you can retrieve the value by calling
[Toys::Tool#get](https://www.rubydoc.info/gems/toys-core/Toys%2FTool:get).

#### Flag Types

Toys recognizes the same syntax used by the standard OptionParser library. This
means you can also declare a flag that can be set either to true or false:

    flag :shout, "--[no-]shout"

If you do not provide any actual flags, Toys will infer a long flag from the
name of the option. Hence, the following two definitions are equivalent:

    flag :shout
    flag :shout, "--shout"

You can declare that a short or long flag takes a value:

    flag :whom, "--whom=VALUE"
    flag :whom, "--whom VALUE"
    flag :whom, "-wVALUE"
    flag :whom, "-w VALUE"

You can also declare the value to be optional:

    flag :whom, "--whom[=VALUE]"
    flag :whom, "--whom [VALUE]"
    flag :whom, "-w[VALUE]"
    flag :whom, "-w [VALUE]"

Note that if you define multiple flags together, they will all be coerced to
the same "type". That is, if one takes a value, they all will implicitly take
a value. (This is the same behavior as OptionParser.) In this example:

    flag :whom, "-w", "--whom=VALUE"

The `-w` flag will also implicitly take a value, because it is defined as a
synonym of another flag that takes a value.

Note also that Toys will raise an error if those flags are incompatible. For
example:

    flag :whom, "-w[VALUE]", "--whom=VALUE"

Raises an error because one flag's value is optional while the other is
required. (Again, this is consistent with OptionParser's behavior.)

#### Flag Acceptors

Flags may use **acceptors** to define how to validate values and convert them
to Ruby objects for your tool to consume. By default, Toys will accept a flag
value string in any form, and expose it to your tool as a raw string. However,
you may provide an acceptor to change this behavior.

Acceptors are part of the OptionParser interface, and are described under the
[type coercion](http://ruby-doc.org/stdlib/libdoc/optparse/rdoc/OptionParser.html#class-OptionParser-label-Type+Coercion)
section. For example, you can provide the `Integer` class as an acceptor, which
will validate that the argument is a well-formed integer, and convert it to an
integer during parsing:

    tool "args-demo" do
      flag :age, accept: Integer
      def run
        puts "Next year I will be #{age + 1}"  # Age is an integer
        ...

If you pass a non-integer for this flag value, Toys will report a usage error.

You may use any of the ready-to-use coercion types provided by OptionParser,
including the special types such as
[OptionParser::DecimalInteger](http://ruby-doc.org/stdlib/libdoc/optparse/rdoc/OptionParser.html#DecimalInteger)
and
[OptionParser::OctalInteger](http://ruby-doc.org/stdlib/libdoc/optparse/rdoc/OptionParser.html#OctalInteger).

You may also create **custom acceptors**. See the
[section below on Custom Acceptors](#Custom_Acceptors) for more information.

#### Defaults and Handlers

Currently, flags are always optional; a flag can appear in a command line zero,
one, or any number of times. If a flag is not passed in the command line
arguments for a tool, by default its corresponding option value will be `nil`.

You may change this by providing a default value for a flag:

    flag :age, accept: Integer, default: 21

If you pass a flag multiple times on the command line, by default the *last*
appearance of the flag will take effect. That is, suppose you define this flag:

    flag :shout, "--[no-]shout"

Now if you pass `--shout --no-shout`, then the value of the `:shout` option
will be `false`, i.e. the last value set on the command line. This is because a
flag *sets* its option value, replacing any previously set value. You may
change this behavior by providing a **handler**.

A handler is a proc that governs what a flag does to its option value. It takes
two arguments, the new value given, and the previously set value (which might
be the default value if this is the first appearance of the flag), and returns
the new value that should be set. So effectively, the default behavior is
equivalent to the following handler:

    flag :shout, "--[no-]shout", handler: proc { | val, _prev| val }

For example, most tools automatically get a "--verbose" flag. This flag may
appear any number of times, and each appearance increases the verbosity. The
value of this verbosity is an integer. This flag is provided automatically by
Toys, and its implementation looks something like this:

    flag Toys::Tool::Keys::VERBOSITY, "-v", "--verbose",
         default: 0,
         handler: proc { |_val, prev| prev + 1 }

Similarly, the "--quiet" flag, which decreases the verbosity, is implemented
like this:

    flag Toys::Tool::Keys::VERBOSITY, "-q", "--quiet",
         default: 0,
         handler: proc { |_val, prev| prev - 1 }

Note that both flags affect the same option value, `VERBOSITY`. The first
increments it each time it appears, and the second decrements it. A tool can
query this option and get an integer telling the requested verbosity level, as
you will see [below](#Logging_and_Verbosity).

#### Descriptions and the Flags DSL

Flags may also have short and long descriptions, which are displayed in online
help. Set descriptions via the `desc:` and `long_desc:` arguments to the flag
directive. The `desc:` argument takes a single string description, while the
`long_desc:` argument takes an array of strings. Here is an example:

    flag :my_flag, "--my-flag",
         desc: "This is a short description for the arg",
         long_desc: ["Long descriptions may have multiple lines.",
                     "This is the second line."]

See the [above section on Descriptions](#Tool_Descriptions) for more information on
how descriptions are rendered and word wrapped.

Because long descriptions may be unwieldly to write as a hash argument in this
way, Toys provides an alternate syntax for defining flags using a block.

    flag :my_flag do
      flags "--my-flag"
      desc "This is a short description for the flag"
      long_desc "Long desc can be set as multiple lines together,",
                "like this second line."
      long_desc "Or you can call long_desc again to add more lines."
    end

For detailed info on configuring an flag using a block, see the
[Toys::DSL::Flag class](https://www.rubydoc.info/gems/toys-core/Toys/DSL/Flag).

### Tool Execution Basics

When you run a tool from the command line, Toys will build the tool based on
its definition in a Toys file, and then it will attempt to execute it by
calling the `run` method. Normally, you should define this method in each of
your tools.

Note: If you do not define the `run` method for a tool, Toys provides a default
implementation that displays the tool's help screen. This is typically used for
namespaces, as we shall see [below](#Namespaces_and_Subtools). Most tools,
however, should define `run`.

Let's revisit the "greet" example we covered earlier.

    tool "greet" do
      optional_arg :whom, default: "world"
      flag :shout, "-s", "--shout"

      def run
        greeting = "Hello, #{whom}!"
        greeting.upcase! if shout
        puts greeting
      end
    end

Note that you can produce output or interact with the console using the normal
Ruby `$stdout`, `$stderr`, and `$stdin` streams.

Note also how the `run` method can access values that were assigned by flags or
positional arguments by just calling a method with that flag or argument name.
When you declare a flag or argument, if the option name is a symbol that is a
valid Ruby method name, Toys will provide a method of that name that you can
call to get the value.

If you create a flag or argument whose option name is not a symbol _or_ is not
a valid method name, you can still get the value by calling the
[Toys::Tool#get](https://www.rubydoc.info/gems/toys-core/Toys%2FTool:get)
method. For example:

    tool "greet" do
      # The name "whom-to-greet" is not a valid method name.
      optional_arg "whom-to-greet", default: "world"
      flag :shout, "-s", "--shout"

      def run
        # We can access the "whom-to-greet" option using the "get" method.
        greeting = "Hello, #{get('whom-to-greet')}!"
        greeting.upcase! if shout
        puts greeting
      end
    end

If a tool's `run` method finishes normally, Toys will exit with a result code
of 0, indicating success. You may exit immediately and/or provide a nonzero
result by calling the
[Toys::Tool#exit](https://www.rubydoc.info/gems/toys-core/Toys%2FTool:exit)
method:

    def run
      puts "Exiting with an error..."
      exit(1)
      puts "Will never get here."
    end

If your `run` method raises an exception, Toys will display the exception and
exit with a nonzero code.

Finally, you may also define additional methods within the tool. These are
available to be called by your `run` method, and can be used to decompose your
tool implementation. Here's a contrived example:

    tool "greet-many" do
      # Support any number of arguments on the command line
      remaining_args :whom, default: ["world"]
      flag :shout, "-s", "--shout"

      # You can define helper methods like this.
      def greet(name)
        greeting = "Hello, #{name}!"
        greeting.upcase! if shout
        puts greeting
      end

      def run
        whom.each do |name|
          greet(name)
        end
      end
    end

This should be enough to get you started implementing tools. A variety of
additional features are available for your tool implementation and will be
discussed further below. But first we will cover a few important topics.

### Namespaces and Subtools

Like many command line frameworks, Toys supports **subtools**. You may, for
example create a tool called "test" that runs your tests for a particular
project, but you might also want "test unit" and "test integration" tools to
run specific subsets of the test suite. One way to do this, of course, is for
the "test" tool to parse "unit" or "integration" as arguments. However, you
could also define them as separate tools, subtools of "test".

To define a subtool, create nested `tool` directives. Here's a simple example:

    tool "test" do
      tool "unit" do
        def run
          puts "run unit tests here..."
        end
      end

      tool "integration" do
        def run
          puts "run integration tests here..."
        end
      end
    end

You can now invoke them like this:

    toys test unit
    toys test integration

Notice in this case, the parent "test" tool itself has no `run` method. This is
a common pattern: "test" is just a "container" for tools, a way of organizing
your tools. In Toys terminology, it is called a **namespace**. But it is still
a tool, and it can still be run:

    toys test

As discussed earlier, Toys provides a default implementation that displays the
help screen, which includes a list of the subtools and their descriptions.

As another example, the "root" tool is also normally a namespace. If you just
run Toys with no arguments:

    toys

The root tool will display the overall help screen for Toys.

Although it is a less common pattern, it is possible for a tool that has
subtools to have its own `run` method:

    tool "test" do
      def run
        puts "run all tests here..."
      end

      tool "unit" do
        def run
          puts "run only unit tests here..."
        end
      end

      tool "integration" do
        def run
          puts "run only integration tests here..."
        end
      end
    end

Now running `toys test` will run its own implementation.

(Yes, it is even possible to write a `run` method for the root tool. I don't
recommend doing so, because then you lose the root tool's useful default
implementation that lists all your tools.)

Toys allows subtools to be nested arbitrarily deep. In practice, however, more
than two or three levels of hierarchy can be confusing to use.

## Understanding Toys Files

Toys commands are defined in Toys files. We covered the basic syntax for these
files in the [above section on defining tools](#Defining_Tools). In this
section, we will take a deeper look at what you can do with Toys files.

### Toys Directories

So far we have been defining tools by writing a Toys file named `.toys.rb`
located in the current working directory. This works great if you have a small
number of fairly simple tools, but if you are defining many tools or tools with
long or complex implementations, you may find it better to split your tools in
separate files. You can have Toys load tools from multiple files by creating a
**Toys directory**.

A Toys directory is a directory called `.toys` located in the current working
directory. (Again, note the leading period.) Ruby files inside a Toys directory
(or any of its subdirectories) are loaded when Toys looks for tool definitions.
Furthermore, the name of the Ruby file (and indeed its path relative to the
Toys directory) determines which tool it defines.

For example, one way to create a "greet" tool, as we saw before, is to write a
`.toys.rb` file in the current directory, and populate it like this:

    tool "greet" do
      optional_arg :whom, default: "world"
      def run
        puts "Hello, #{whom}"
      end
    end

You could also create the same tool by creating a `.toys` directory, and then
creating a file `greet.rb` inside that directory.

    (current directory)
    |
    +- .toys/
       |
       +- greet.rb

The contents of `greet.rb` would be:

    optional_arg :whom, default: "world"
    def run
      puts "Hello, #{whom}"
    end

Notice that we did not use a `tool "greet"` block here. That is because the
name of the file `greet.rb` already provides a tool context: Toys already knows
that we are defining a "greet" tool.

If you do include a `tool` block inside the `greet.rb` file, it will create a
*subtool* of `greet`. In other words, the path to the Ruby file defines a
"starting point" for the names of tools defined in that file.

If you create subdirectories inside a Toys directory, their names also
contribute to the namespace of created tools. For example, if you create a
directory `.toys/test` and a file `unit.rb` under that directory, it will
create the tool `test unit`.

    (current directory)
    |
    +- .toys/
       |
       +- greet.rb   <-- defines "greet" (and subtools)
       |
       +- test/
          |
          +- unit.rb   <-- defines "test unit" (and its subtools)

Once again, `test unit` is the "starting point" for tools defined in the
`.toys/test/unit.rb` file. Declarations and methods at the top level of that
file will define the `test unit` tool. Any `tool` blocks you add to that file
will define subtools of `test unit`.

#### Index Files

The file name `.toys.rb` can also be used inside Toys directories and
subdirectories. Such files are called **index files**, and they create tools
with the *directory* as the "starting point" namespace. For example, if you
create an index file directly underneath a `.toys` directory, it will define
top level tools (just like a `.toys.rb` file in the current directory.) An
index file located inside `.toys/test` will define tools with `test` as the
"starting point" namespace.

    (current directory)
    |
    +- .toys/
       |
       +- .toys.rb   <-- index file, defines tools at the top level
       |
       +- greet.rb   <-- defines "greet" (and subtools)
       |
       +- test/
          |
          +- .toys.rb   <-- index file, defines "test" (and its subtools)
          |
          +- unit.rb   <-- defines "test unit" (and its subtools)

Index files give you some flexibility for organizing your tools. For example,
if you have a number of subtools of `test`, including a lot of small tools and
one big complex subtool called `unit`, you might define all the simple tools in
the index file `.toys/test/.toys.rb`, while defining the large `test unit` tool
in the separate file `.toys/test/unit.rb`.

Toys also loads index files first before other files in the directory. This
means they are convenient places to define shared code that can be used by all
the subtools defined in that directory, as we shall see later in the
[section on sharing code](#Sharing_Code).

### The Toys Search Path

So far we have seen how to define tools by writing a `.toys.rb` file in the
current directory, or by writing files inside a `.toys` directory in the
current directory. These tools are "scoped" to the current directory. If you
move to a different directory, they may not be available.

When Toys runs, it looks for tools in a **search path**. Specifically:

(1) It looks for a `.toys.rb` file and/or a `.toys` directory in the *current
    working directory*.
(2) It does the same in the *parent directory* of the current directory, and
    then its parent, all the way up to the root of the file system.
(3) It does the same in the current user's *home directory*.
(4) It does the same in the system configuration directory (i.e. `/etc` on unix
    systems)

It uses the *first* implementation that it finds for the requested tool. For
example, if the tool `greet` is defined in the `.toys.rb` file in the current
working directory, and also in the `.toys/greet.rb` file of the parent
directory, it will use the version in the current directory.

This means you could write a default implementation for a tool in your home
directory, and override it in the current directory. For example, you could
define a tool `get-credentials` in your home directory that gets credentials
you need for *most* of your projects. But maybe on particular project requires
different credentials, so you could define a different `get-credentials` tool
in that project's directory.

While a tool can be overridden when it is defined at different points in the
search path, it is *not* allowed to provide multiple definitions of a tool at
the *same* point in the search path. For example, if you define the `greet`
tool twice in the same `.toys.rb` file, Toys will report an error. Perhaps less
obviously, if you define `greet` in the `.toys.rb` file in the current
directory, and you also define it in the `.toys/greet.rb` file in the same
current directory, Toys will also report an error, since both are defined at
the same point (the current directory) in the search path.

#### Global Tools

Note that in the search path above, steps (1) and (2) are *context-dependent*.
That is, they may be different depending on what directory you are in. However,
steps (3) and (4) are *not* context-dependent, and are searched regardless of
where you are located. Tools defined here are **global**, available everywhere.

By default, global tools are defined in your home directory and the system
configuration directory. However, you can change this by defining the
environment variable `TOYS_PATH`. This environment variable should contain a
colon-delimited list of paths that should be searched for global tools. If you
do define it, it replaces (3) and (4) with the paths you specify.

## The Execution Environment

This section describes the context and resources available to your tool when it
is running; that is, what you can call from your tool's `run` method.

Generally, your tool is executed in an object of type
[Toys::Tool](https://www.rubydoc.info/gems/toys-core/Toys/Tool). This class
defines a number of methods, and provides access to a variety of data and
objects relevant to your tool. We have already seen earlier how to use the
[Toys::Tool#get](https://www.rubydoc.info/gems/toys-core/Toys%2FTool:get)
method to retrieve option values, and how to use the
[Toys::Tool#exit](https://www.rubydoc.info/gems/toys-core/Toys%2FTool:exit)
method to exit immediately and return an exit code. Now we will cover other
resources available to your tool.

### Built-in Context

The options set by your tool's flags and command line arguments are only a
subset of the data you can access. A variety of other data and objects are
also accessible using the
[Toys::Tool#get method](https://www.rubydoc.info/gems/toys-core/Toys%2FTool:get)
For example, you can get the full name of the tool being executed like this:

    def run
      puts "Current tool is #{get(TOOL_NAME)}"
    end

The `TOOL_NAME` constant above is a well-known key that corresponds to the full
name (as an array of strings) of the running tool. A variety of well-known keys
are defined in the
[Toys::Tool::Keys module](https://www.rubydoc.info/gems/toys-core/Toys/Tool/Keys).
They include information about the current execution, such as the tool name and
the original command line arguments passed to it (before they were parsed).
They also include some internal Toys objects, which can be used to do things
like write to the log or look up and call other tools.

Most of the important context also can be accessed from convenience methods.
For example, the `TOOL_NAME` is also available from the
[Toys::Tool#tool_name method](https://www.rubydoc.info/gems/toys-core/Toys%2FTool:tool_name):

    def run
      puts "Current tool is #{tool_name}"
    end

Let's take a look at a few things your tool can do with the objects you can
access from built-in context.

### Logging and Verbosity

Toys provides a Logger (a simple instance of the Ruby standard library logger
that writes to standard error) for your tool to use to report status
information. You can access this logger via the `LOGGER` context key, or the
[Toys::Tool#logger method](https://www.rubydoc.info/gems/toys-core/Toys%2FTool:logger).
For example:

    def run
      logger.warn "Danger Will Robinson!"
    end

The current logger level is controlled by the verbosity. Verbosity is an
integer context value that you can retrieve using the `VERBOSITY` context key
or the
[Toys::Tool#verbosity method](https://www.rubydoc.info/gems/toys-core/Toys%2FTool:verbosity).
The verbosity is set to 0 by default. This corresponds to a logger level of
`WARN`. That is, warnings, errors, and fatals are displayed, while infos and
debugs are not. However, [as we saw earlier](#Standard_Flags), most tools
automatically respond to the `--verbose` and `--quiet` flags, (or `-v` and
`-q`), which increment and decrement the verbosity value, respectively. If you
run a tool with `-v`, the verbosity is incremented to 1, and the logger level
is set to `INFO`. If you set `-q`, the verbosity is decremented to -1, and the
logger level is set to `ERROR`. So by using the provided logger, a tool can
easily provide command line based control of the output verbosity.

### Running Tools from Tools

A common operation a tool might want to do is "call" another tool. This can be
done via the CLI object, which you can retrieve using the `CLI` key or the
[Toys::Tool#cli method](https://www.rubydoc.info/gems/toys-core/Toys%2FTool:cli).
These return the current instance of
[Toys::CLI](https://www.rubydoc.info/gems/toys-core/Toys/CLI) which is the
"main" interface to Toys. In particular, it provides the
[Toys::CLI#run method](https://www.rubydoc.info/gems/toys-core/Toys%2FCLI:run)
which can be used to call another tool:

    def run
      status = cli.run("greet", "rubyists", "-v")
      exit(status) unless status.zero?
    end

Pass the tool name and arguments as arguments to the run method. It will
execute, and return a process status object (i.e. 0 for success, and nonzero
for error). Make sure you handle the exit status. For example, in most cases,
you should probably exit if the tool you are calling returns a nonzero code.

You may also use the `exec` mixin [described below](#Executing_Subprocesses) to
run a tool in a separate process. This is particularly useful if you need to
capture or manipulate that tool's input or output.

### Helper Methods and Mixins

The methods of [Toys::Tool](https://www.rubydoc.info/gems/toys-core/Toys/Tool)
are not the only methods available for your tool to call. We
[saw earlier](#Tool_Execution_Basics) that a tool can define additional methods
that you can use as helpers.

You can also include **mixins**, which are modules that bring in a whole set of
helper methods. Include a mixin using the `include` directive:

    tool "greet" do
      include :terminal
      def run
        puts "This is a bold line.", :bold
      end
    end

A mixin may be specified by providing a module itself, or by providing a
**mixin name**. In the above example, we used `:terminal`, which is the name
of a built-in mixin that Toys provides. Among other things, it defines a
special `puts` method that lets you include style information such as `:bold`,
which affects the display on ANSI-capable terminals.

For details on the built-in mixins provided by Toys, see the modules under
[Toys::StandardMixins](https://www.rubydoc.info/gems/toys-core/Toys/StandardMixins).
We will look at a few examples of the use of these mixins below. Built-in
mixins have names that are symbols.

You can also define your own mixins, as we will see in the
[upcoming section on defining mixins](#Defining-Mixins).

### Executing Subprocesses

Another common operation you might do in a tool is to execute other binaries.
For example, you might write a tool that shells out to `scp` to copy files to
a remote server.

Ruby itself provides a few convenient methods for simple execution, such as the
[Kernel#system](http://ruby-doc.org/core/Kernel.html#method-i-system) method.
However, these typically provide limited ability to control or interact with
subprocess streams, and you need to remember to handle the exit status
yourself. If you do want to exert any control over subprocesses, you can use
[Process.spawn](http://ruby-doc.org/core/Process.html#method-c-spawn), or a
higher-level wrapper such as the
[open3 library](http://ruby-doc.org/stdlib/libdoc/open3/rdoc/index.html).

Another alternative is to use the `:exec` built-in mixin. This mixin provides
convenient methods for the common cases of executing subprocesses and capturing
their output, and a powerful block-based interface for controlling streams. The
exec mixin also lets you set a useful default option that causes the tool to
exit automatically if one of its subprocesses exits abnormally.

The exec mixin provides methods for running several different kinds of
subprocesses:

*   Normal processes started by the operating system.
*   Another Ruby process.
*   A shell script.
*   Another tool run in a separate (forked) process.
*   A block run in a separate (forked) process.

For more information, see the
[Toys::StandardMixins::Exec mixin module](https://www.rubydoc.info/gems/toys-core/Toys/StandardMixins/Exec)
and the underyling library
[Toys::Utils::Exec](https://www.rubydoc.info/gems/toys-core/Toys/Utils/Exec).

### Formatting Output

Interacting with the user is a very common function of a command line tool, and
many modern tools include intricately designed and styled output, and terminal
effects such as progress bars and spinners. Toys provides several mixins that
can help create nicer interfaces.

First, there is `:terminal`, which provides some basic terminal features such
as styled output and simple spinners. For information, see the
[Toys::StandardMixins::Terminal mixin module](https://www.rubydoc.info/gems/toys-core/Toys/StandardMixins/Terminal)
and the underyling library
[Toys::Utils::Terminal](https://www.rubydoc.info/gems/toys-core/Toys/Utils/Terminal).

If you prefer the venerable Highline library interface, Toys provides a mixin
called `:highline` that automatically installs the highline gem (version 2.x)
if it is not available, and makes a highline object available to the tool. For
more information, see the
[Toys::StandardMixins::Highline mixin module](https://www.rubydoc.info/gems/toys-core/Toys/StandardMixins/Highline).

You may also use other third-party gems such as
[tty](https://github.com/piotrmurach/tty). The section below on
[useful gems](#Useful_Gems) provides some examples.

## Sharing Code

As you accumulate additional and more complex tools, you may find that some of
your tools need to share some common configuration, data, or logic. You might,
for example, have a set of admin scripts that need to do some common
authentication. This section describes several techniques for sharing code
between tools, and describes the scope of Ruby structures, such as methods,
classes, and constants, that you might define in your tools.

### Defining Mixins

We [saw earlier](#Helper_Methods_and_Mixins) that you can mix a module (with
all its methods) into your tool using the `include` directive. You can specify
a module itself, or the name of a built-in mixin such as `:exec` or
`:terminal`. But you can also define your own mixin using the `mixin`
directive. A mixin defined in a tool can be `include`d in that tool or any of
its subtools or their subtools, recursively, so it's a useful way to share
code. Here's how that works.

Define a mixin using the `mixin` directive, and give it a name and a block. The
mixin name must be a string. (Symbols are reserved for built-in mixins.) In the
block, you can define methods that will be made available to any tool that
includes the mixin, in the same way that you can include a Ruby module.

(Note that, unlike full modules, mixins allow only methods to be shared. Mixins
do not support constants. See the next section on
[using constants](#Using_Constants) to learn how Toys handles constants.)

Here's an example. Suppose you had common setup code that you wanted to share
among your testing tools.

    tool "test" do
      # Define a mixin, which is just a collection of methods.
      mixin "common_test_code" do
        def setup
          # Do setup here
        end
      end

      tool "unit" do
        # Include the mixin by name
        include "common_test_code"
        def run
          setup  # Mixin methods are made available
          puts "run only unit tests here..."
        end
      end

      tool "integration" do
        include "common_test_code"
        def run
          setup
          puts "run only integration tests here..."
        end
      end
    end

A mixin is available to the tool in which it is defined, and any subtools and
descendants defined at the same point in the Toys search path, but not from
tools defined in a different point in the search path. For example, if you
define a mixin in a file located in a `.toys` directory, it will be visible to
descendant tools defined in that same directory, but not in a different `.toys`
directory.

A common technique, for example, would be to define a mixin in the index file
in a Toys directory. You can then include it from any subtools defined in other
files in that same directory.

#### Mixin initializers

Sometimes a mixin will want to initialize some state before the tool executes.
For example, the `:highline` mixin creates an instance of Highline during tool
initialization. To do so, provide a `to_initialize` block in the mixin block.
The initializer block is called within the context of the tool before it
initializes, so it has access to the tool's built-in context and options.

If you provide extra arguments when you `include` a mixin, those are passed to
the initializer block.

For example, suppose the `"common_test_code"` mixin needs to behave differently
depending on the type of tests (unit vs integration). Let's have the subtools
pass a value to the mixin's initializer:

    tool "test" do
      mixin "common_test_code" do
        # Initialize the mixin, and receive the argument passed to include
        to_initialize do |type|
          # Initializers are called in the context of the tool, and so can
          # affect the tool's state.
          set(:test_type, type)
        end

        def setup
          puts "Setting up #{get(:test_type)}..."
        end
      end

      tool "unit" do
        # Pass an extra argument to include
        include "common_test_code", "unit"
        def run
          setup
          puts "run only unit tests here..."
        end
      end

      tool "integration" do
        include "common_test_code", "integration"
        def run
          setup
          puts "run only integration tests here..."
        end
      end
    end

### Using Constants

You can define and use Ruby constants, i.e. names beginning with a capital
letter, in a Toys file. However, they are subject to Ruby's rules regarding
constant scope and lookup, which can be confusing, especially in a DSL. Toys
tries to simplify those rules and make constant behavior somewhat tractable,
but if you do use constants (which includes modules and classes defined in a
Toys file), it is important to understand how they work.

Constants in Toys are visible only within the Toys file in which they are
defined. They normally behave as though they are defined at the "top level" of
the file. Even if you define a constant lexically "inside" a tool or a mixin,
the constant does _not_ end up connected to that tool or mixin; it is defined
at the file level.

    tool "test" do
      tool "unit" do
        # This constant is now usable for the rest of the file
        API_KEY_FOR_TESTING = "12345"
        def run
          # It is visible here
          puts API_KEY_FOR_TESTING
        end
      end

      tool "integration" do
        def run
          # And it is still visible here
          puts API_KEY_FOR_TESTING
        end
      end
    end

(Note it is still possible to attach constants to a tool or mixin by defining
them with `self::`. However, this isn't very common practice in Ruby.)

Because of this, it is highly recommended that you define constants only at the
top level of a Toys file, so it doesn't "look" like it is scoped to something
smaller. In particular, do not attempt to define constants in a mixin, unless
you scope them with `self::`.

Modules and classes defined using the `module` or `class` keyword, are also
constants, and thus follow the same rules. So you could, for example, define a
"mixin" module like this:

    module CommonTestCode
      include Toys::Mixin
      def setup
        # Do setup here
      end
    end

    tool "test" do
      tool "unit" do
        # Include the modules as a mixin
        include CommonTestCode
        def run
          setup  # Module methods are made available
          puts "run only unit tests here..."
        end
      end

      tool "integration" do
        include CommonTestCode
        def run
          setup
          puts "run only integration tests here..."
        end
      end
    end

The difference between this technique and using the `mixin` directive we saw
earlier, is the scope. The module here is accessed via a constant, and so, like
any constant, it is visible only in the same file it is defined in. The `mixin`
directive creates mixins that are visible from _all_ files at the same point in
the search path.

Not also, when you define a mixin in this way, you should include `Toys::Mixin`
in the module, as illustrated above. This makes `to_initialize` available in
the module.

### Templates

One final way to share code is to expand a **template**.

A template is a class that inserts a bunch of lines into a Toys file. It is
often used to "instantiate" prefabricated tools. For instance, Toys comes with
a template called "minitest" that can generate a test tool for you. You
instantiate it using the `expand` directive in your Toys file, like this:

    expand :minitest

And it will generate a tool called "test" that runs your test suite.

Most templates generate one or more complete tools. However, it is possible for
a template to generate just part of a tool, such as one or more description
directives. In general, expanding a template simply adds directives to your
Toys file.

Many templates can be configured with options such as the name of the tool to
generate, or details of the tool's behavior. This is done by passing additional
arguments to the `expand` directive, such as:

    expand :minitest, name: "unit-test", warnings: true

Alternatively, you may provide a block to `expand`. It will yield the template
to your block, letting you modify its properties:

    expand :minitest do |t|
      t.name = "unit-test"
      t.warnings = true
    end

Toys provides several built-in templates that are useful for project and gem
development, including templates that generate build, test, and documentation
tools. The `:minitest` template illustrated above is one of these built-in
templates. Like built-in mixins, built-in template names are always symbols.
You can read more about them in the next section on using
[Toys as a Rake replacement](#Toys_as_a_Rake_Replacement).

You may also write your own templates. Here's how...

#### Defining Templates

One way to define a template is to use the `template` directive. Like the
`mixin` directive, this creates a named template that you can access inside the
current tool and any of its subtools. Also, like mixins, your template name
must be a string.

Following is a simple template example:

    template "greet" do
      def initialize(name: "greet", whom: "world")
        @name = name
        @whom = whom
      end
      attr_accessor :name
      attr_accessor :whom

      to_expand do |template|
        tool template.name do
          desc "A greeting tool generated from a template"
          to_run do
            puts "Hello, #{template.whom}!"
          end
        end
      end
    end

    expand "greet"

    expand "greet", name: "greet-ruby", whom: "ruby"

Above we created a template called "greet". A template is simply a class. It
will typically have a constructor, and methods to access configuration
properties. When the template is expanded, the class gets instantiated, and you
can set those properties.

Next, a template has a `to_expand` block. This block contains the Toys file
directives that should be generated by the template. The template object is
passed to the block, so it can access the template configuration when
generating directives. The "greet" template in the above example generates a
tool whose name is set by the template's `name` property.

Notice that in the above example, we used `to_run do`, providing a _block_ for
the tool's execution, rather than `def run`, providing a method. Both forms are
valid and will work in a template (as well in a normal Toys file), but the
block form is often useful in a template because you can access the `template`
variable inside the block, whereas it would not be accessible if you defined a
method. Similarly, if your template generates helper methods, and the body of
those methods need access to the `template` variable, you can use
[Module#define_method](http://ruby-doc.org/core/Module.html#method-i-define_method)
instead of `def`.

By convention, it is a good idea for configuration options for your template to
be settable *both* as arguments to the constructor, *and* as `attr_accessor`
properties. In this way, when you expand the template, options can be provided
either as arguments to the `expand` directive, or in a block passed to the
directive by setting properties on the template object.

#### Template Classes

Finally, templates are classes, and you can create a template directly as a
class by including the
[Toys::Template](https://www.rubydoc.info/gems/toys-core/Toys/Template) module
in your class definition.

    class GreetTemplate
      include Toys::Template

      def initialize(name: "greet", whom: "world")
        @name = name
        @whom = whom
      end
      attr_accessor :name
      attr_accessor :whom

      to_expand do |template|
        tool template.name do
          desc "A greeting tool generated from a template"
          to_run do
            puts "Hello, #{template.whom}!"
          end
        end
      end
    end

    expand GreetTemplate, name: "greet-ruby", whom: "ruby"

Remember that classes created this way are constants, and so the name
`GreetTemplate` is available only inside the Toys file where it was defined.

You must `include Toys::Template` if you define a template directly as a class,
but you can omit it if you use the `template` directive to define the template.

Defining templates as classes is also a useful way for third-party gems to
provide Toys integration. For example, suppose you are writing a code analysis
gem, and you want to make it easy for your users to create a Toys tool that
invokes your analysis. Just write a template class in your gem, maybe named
`MyAnalysis::ToysTemplate`. Now, just instruct your users to include the
following in their Toys file:

    require "my_analysis"
    expand MyAnalysis::ToysTemplate

## Using Third-Party Gems

The Ruby community has developed many resources for building command line
tools, including a variety of gems that provide alternate command line parsing,
control of the ANSI terminal, formatted output such as trees and tables, and
effects such as hidden input, progress bars, various subprocess tools, and so
forth.

This section describes how to use a third-party gem in your tool.

### Activating Gems

The toys binary itself uses only two gems: **toys** and **toys-core**. It has
no other gem dependencies. However, if you want to use a third-party gem in
your tool, Toys provides a convenient mechanism to ensure the gem is installed.

To access the gem services, include the `:gems` mixin. This mixin adds a `gem`
directive to ensure a gem is installed and activated when you're defining a
tool, and a `gem` method to ensure a gem is available when you're running a
tool.

Both the `gem` directive and the `gem` method take the name of the gem, and an
optional set of version requirements. If a gem matching the given version
requirements is installed, it is activated. If not, the gem is installed (which
the user can confirm or abort). Or, if Toys is being run in a bundle, a message
is printed informing the user that they need to add the gem to their Gemfile.

For example, here's a way to configure a tool with flags for each of the
HighLine styles. Because highline is needed to decide what flags to define, we
use the `gem` directive to ensure highline is installed while the tool is being
defined.

    tool "highline-styles-demo" do
      include :gems
      gem "highline", "~> 2.0"
      require "highline"
      HighLine::BuiltinStyles::STYLES.each do |style|
        style = style.downcase
        flag style.to_sym, "--#{style}", "Apply #{style} to the text"
      end
      def run
        # ...

Here's an example tool that just runs `rake`. Because it requires rake to be
installed in order to *run* the tool, we call the
[Toys::StandardMixins::Gems#gem](https://www.rubydoc.info/gems/toys-core/Toys%2FStandardMixins%2FGems:gem)
method provided by the `:gems` mixin when running.

    tool "rake" do
      include :gems
      remaining_args :rake_args
      def run
        gem "rake", "~> 12.0"
        Kernel.exec(["rake"] + rake_args)
      end
    end

If a gem satisfying the given version constraints is already activated, it
remains active. If a gem with a conflicting version is already activated, an
exception is raised.

If you are not in the Toys DSL context—for example from a class-based
mixin—you should use
[Toys::Utils::Gems.activate](https://www.rubydoc.info/gems/toys-core/Toys%2FUtils%2FGems.activate)
instead. For example:

    Toys::Utils::Gems.activate("highline", "~> 2.0")

Note these methods are a bit different from the
[gem method](http://ruby-doc.org/stdlib/libdoc/rubygems/rdoc/Kernel.html)
provided by Rubygems. The Toys version attempts to install a missing gem for
you, whereas Rubygems will just throw an exception.

### Useful Gems

Now that you know how to ensure a gem is installed, let's look at some third-
party gems that you might find useful when writing tools.

We already saw how to use the **highline** gem. Highline generally provides two
features: terminal styling, and prompts. For these capabilities and many more,
you might also consider [TTY](https://github.com/piotrmurach/tty). It comprises
a suite of gems that you can use separately or in tandem. Here are a few
examples.

To produce styled output, consider
[Pastel](https://github.com/piotrmurach/pastel).

    tool "fancy-output" do
      def run
        gem "pastel", "~> 0.7"
        require "pastel"
        pastel = Pastel.new
        puts pastel.red("Rubies!")
      end
    end

To create rich user prompts, consider
[tty-prompt](https://github.com/piotrmurach/tty-prompt).

    tool "favorite-language" do
      def run
        gem "tty-prompt", "~> 0.16"
        require "tty-prompt"
        prompt = TTY::Prompt.new
        lang = prompt.select("What is your favorite language?",
                             %w[Elixir Java Python Ruby Rust Other])
        prompt.say("#{lang} is awesome!")
      end
    end

To create tabular output, consider
[tty-table](https://github.com/piotrmurach/tty-table).

    tool "matrix" do
      def run
        gem "tty-table", "~> 0.10"
        require "tty-table"
        table = TTY::Table.new(["Language", "Creator"],
                               [["Ruby", "Matz"],
                                ["Python", "Guido"],
                                ["Elixir", "Jose"]])
        puts table.render(:ascii)
      end
    end

To show progress, consider
[tty-progressbar](https://github.com/piotrmurach/tty-progressbar) for
deterministic processes, or
[tty-spinner](https://github.com/piotrmurach/tty-spinner) for
non-deterministic.

    tool "waiting" do
      def run
        gem "tty-progressbar", "~> 0.15"
        require "tty-progressbar"
        bar = TTY::ProgressBar.new("Waiting [:bar]", total: 30)
        30.times do
          sleep(0.1)
          bar.advance(1)
        end
      end
    end

A variety of other useful gems can also be found in
[this article](https://lab.hookops.com/ruby-cli-gems.html).

## Toys as a Rake Replacement

Toys was designed to organize scripts that may be "scoped" to a project or
directory. Rake is also commonly used for this purpose: you can write a
"Rakefile" that defines rake tasks scoped to a directory. In many cases, Toys
can be used as a replacement for Rake. Indeed, the Toys repository itself
contains a `.toys.rb` file that defines tools for running tests, builds, and so
forth, instead of a Rakefile that is otherwise often used for this purpose.

This section will explore the differences between Toys and Rake, and describe
how to use Toys for some of the things traditionally done with Rake.

### Comparing Toys and Rake

Although Toys and Rake serve many of the same use cases, they have very
different design goals, and it is useful to understand them.

Rake's design is based on the classic "make" tool often provided in unix
development environments. This design focuses on _targets_ and _dependencies_,
and is meant for a world where you invoke an external compiler tool whenever
changes are made to an individual source file or any of its dependencies. This
"declarative" approach expresses very well the build process for programs
written in C and similar compiled languages.

Ruby, however, does not have an external compiler, and certainly not one that
requires separate invocation for each source file as does the C compiler. So
although Rake does support file dependencies, they are much less commonly used
than in their Makefile cousins. Instead, in practice, most Rake tasks are not
connected to a dependency at all; they are simply standalone tasks, what would
be called "phony" targets in Makefile parlance. Such tasks are more imperative
than declarative.

The Toys approach to build tools simply embraces the fact that our build
processes already tend to be imperative. So unlike Rake, Toys does not provide
syntax for describing targets and dependencies, since we generally don't have
them in Ruby programs. Instead, it is optimized for writing tools.

For example, Rake provides a primitive mechanism for passing arguments to a
task, but it is clumsy and quite different from most unix programs. However, to
do otherwise would clash with Rake's design goal of treating tasks as targets
and dependencies. Toys does not have those design goals, so it is able to
embrace the familiar ways to pass command line arguments.

Toys actually borrows some of its design from the "mix" build tool used for
Elixir and Erlang programs. Unlike C, the Erlang and Elixir compilers do their
own dependency management, so mix does not require those capabilities. Instead,
it focuses on making it easy to define imperative tasks.

All told, this boils down to the principle of using the best tool for the job.
There will be times when you need to express file-based dependencies in some of
your build tasks. Rake will continue to be your friend in those cases. However,
for high level tasks such as "run my tests", "build my YARD documentation", or
"release my gem", you may find Toys easier to use.

### From Rakefiles to Toys Files

If you want to migrate some of your project's build tasks from Rake to Toys,
there are some common patterns.

When you use Rake for these tasks, you will typically require a particular file
from your Rakefile, and/or write some code. Different tools will have different
mechanisms for generating tasks. For example, a test task might be defined like
this:

    require "rake/testtask"
    Rake::TestTask.new do |t|
      t.test_files = FileList["test/test*.rb"]
    end

In Toys, templates are the standard mechanism for generating tools.

    expand :minitest do |t|
      t.files = ["test/test*.rb"]
    end

The following sections will describe some of the built-in templates provided by
Toys to generate common build tools.

Note that Rakefiles and Toys files can coexist in the same directory, so you
can use either or both tools, depending on your needs.

### Running Tests

Toys provides a built-in template for minitest, called `:minitest`. It is
implemented by the template class {Toys::Templates::Minitest}, and it uses the
minitest gem, which is provided with most recent versions of Ruby. The
following directive uses the minitest template to create a tool called `test`:

    expand :minitest, files: ["test/test*.rb"], libs: ["lib", "ext"]

See the {Toys::Templates::Minitest} documentation for details on the various
options.

If you want to enforce code style using the "rubocop" gem, you can use the
built-in `:rubocop` template. The following directive uses this template to
create a tool called `rubocop`:

    expand :rubocop

See the {Toys::Templates::Rubocop} documentation for details on the available
options.

### Building and Releasing Gems

The `:gem_build` built-in template can generate a variety of build and release
tools for gems, and is a useful alternative to the Rake tasks provided by
bundler. It is implemented by {Toys::Templates::GemBuild}. The following
directive uses this template to create a tool called `build`:

    expand :gem_build

The `:gem_build` template by default looks for a gemspec file in the current
directory, and builds that gem into a `pkg` directory. You can also build a
specific gem if you have multiple gemspec files.

You may also configure the template so it also releases the gem to Rubygems
(using your stored Rubygems credentials), by setting the `push_gem` option.
For example, here is how to generate a "release" tool that builds and releases
your gem:

    expand :gem_build, name: "release", push_gem: true

See the {Toys::Templates::GemBuild} documentation for details on the various
options for build tools.

To create a "clean" tool, you can use the `:clean` built-in template. For
example:

    expand :clean, paths: ["pkg", "doc", "tmp"]

See the {Toys::Templates::Clean} documentation for details on the various
options for clean.

### Building Documentation

Toys provides an `:rdoc` template for creating tools that generate RDoc
documentation, and a `:yardoc` template for creating tools that generate YARD.
Both templates provide a variety of options for controlling documentation
generation. See {Toys::Templates::Rdoc} and {Toys::Templates::Yardoc} for
detailed information.

Here's an example for YARD, creating a tool called `yardoc`:

    expand :yardoc, protected: true, markup: "markdown"

### Gem Example

Let's look at a complete example that combines the techniques above to provide
all the basic tools for a Ruby gem. It includes:

* A testing tool that can be run with `toys test`
* Code style checking using Rubocop, run with `toys rubocop`
* Documentation building using Yardoc, run with `toys yardoc`
* Gem building, run with `toys build`
* Gem build and release to Rubygems.org, run with `toys release`
* A full CI tool, run with `toys ci`, that can be run from your favorite CI
  system. It runs the tests and style checks, and checks (but does not
  actually build) the documentation for warnings and completeness.

Below is the full annotated `.toys.rb` file. For many gems, you could drop this
into the gem source repo with minimal or no modifications. Indeed, it is
nearly identical to the Toys files provided for the **toys** and **toys-core**
gems themselves.

    # This file is .toys.rb

    # A "clean" tool that cleans out gem builds (from the pkg directory), and
    # documentation builds (from doc and .yardoc)
    expand :clean, paths: ["pkg", "doc", ".yardoc"]

    # This is the "test" tool.
    expand :minitest, libs: ["lib", "test"]

    # This is the "rubocop" tool.
    expand :rubocop

    # This is the "yardoc" tool. We cause it to fail on warnings and if there
    # are any undocumented objects, which is useful for CI. We also configure
    # the tool so it recognizes the "--no-output" flag. The CI tool will use
    # this flag to invoke yardoc but suppress output, because it just wants to
    # check for warnings.
    expand :yardoc do |t|
      t.generate_output_flag = true
      t.fail_on_warning = true
      t.fail_on_undocumented_objects = true
    end

    # The normal "build" tool that just builds a gem into the pkg directory.
    expand :gem_build

    # A full gem "release" tool that builds the gem, and pushes it to rubygems.
    # This assumes your local rubygems configuration is set up with the proper
    # credentials.
    expand :gem_build, name: "release", push_gem: true

    # Now we create a full CI tool. It runs the test, rubocop, and yardoc tools
    # and checks for errors. This tool could be invoked from Travis-CI or
    # similar CI system.
    tool "ci" do
      # The :exec mixin provides the exec_tool() method that we will use to run
      # other tools and check their exit status.
      include :exec
      # The :terminal mixin provides an enhanced "puts" method that lets you
      # write styled text to the terminal.
      include :terminal

      # A helper method, that runs a tool and outputs the result. It also
      # terminates if the tool reported an error.
      def run_stage(name, tool)
        if exec_tool(tool).success?
          puts("** #{name} passed", :green, :bold)
          puts
        else
          puts("** CI terminated: #{name} failed!", :red, :bold)
          exit(1)
        end
      end

      # The main run method. It just calls the above helper method for the
      # three tools we want to run for CI
      def run
        run_stage("Tests", ["test"])
        run_stage("Style checker", ["rubocop"])
        run_stage("Docs generation", ["yardoc", "--no-output"])
      end
    end

## Advanced Tool Definition Techniques

This section covers some additional features that are often useful for writing
tools. I've labeled them "advanced", but all that really means is that this
user's guide didn't happen to have covered them until this section. Each of
these features is very useful for certain types of tools, and it is good at
least to know that you *can* do these things, even if you don't use them
regularly.

### Aliases

An **alias** is simply an alternate name for a tool. For example, suppose you
have a tool called `test` that you run with `toys test`. You could define an
alias `t` that points to `test`; then you can run the same tool with `toys t`.

To define an alias, use the `alias_tool` directive:

    tool "test" do
      # Define test tool here...
    end

    alias_tool "t", "test"

You may create an alias of a subtool, but the alias must have the same parent
(namespace) tool as the target tool. For example:

    tool "gem" do
      tool "test" do
        # Define test tool here...
      end

      # Allows you to invoke `toys gem t`
      alias_tool "t", "test"
    end

### Custom Acceptors

We saw earlier that flags and positional arguments can have acceptors, which
control the allowed format, and may also convert the string argument to a Ruby
object. By default, Toys supports the same acceptors recognized by Ruby's
OptionParser library. And like OptionParser, Toys also lets you define your own
acceptors.

Define an acceptor using the `acceptor` directive. You provide a name for the
acceptor, and specify how to validate input strings and how to convert input
strings to Ruby objects. You may then reference the acceptor in that tool or
any of its subtools or their subtools, recursively.

There are several ways to define an acceptor.

You may validate input strings against a regular expression, by passing the
regex to the `acceptor` directive. You may also optionally provide a block to
convert input strings to objects (or omit the block to use the original string
as the option value.) For example, a simple hexadecimal input acceptor might
look like this:

    acceptor("hex", /^[0-9a-fA-F]+$/) { |input| input.to_i(16) }

You may also accept enum values by passing an array of valid values to the
`acceptor` directive. Inputs will be matched against the `to_s` form of the
given values, and will be converted to the value itself. For example, one way
to accept integers from 1 to 5 is:

    acceptor("1to5", [1, 2, 3, 4, 5])

There are various other options. See the reference documentation for
[Toys::DSL::Tool#acceptor](https://www.rubydoc.info/gems/toys-core/Toys%2FDSL%2FTool:acceptor).

An acceptor is available to the tool in which it is defined, and any subtools
and descendants defined at the same point in the Toys search path, but not from
tools defined in a different point in the search path. For example, if you
define an acceptor in a file located in a `.toys` directory, it will be visible
to descendant tools defined in that same directory, but not in a different
`.toys` directory.

A common technique, for example, would be to define an acceptor in the index
file in a Toys directory. You can then include it from any subtools defined in
other files in that same directory.

### Controlling Built-in Flags

Earlier we saw that certain flags are added automatically to every tool:
`--verbose`, `--quiet`, `--help`, and so forth. You may occasionally want to
disable some of these "built-in" flags. There are two ways to do so:

If you want to use one of the built-in flags for another purpose, simply define
the flag as you choose. Flags explicitly defined by your tool take precedence
over the built-ins.

For example, normally two built-in flags are provided to decrease the verbosity
level: `-q` and `--quiet`. If you define `-q` yourself—for example to activate
a "quick" mode—then `-q` will be repurposed for your flag, but `--quiet` will
still be present to decrease verbosity.

    # Repurposes -q to set the "quick" option instead of "quiet"
    flag :quick, "-q"

You may also completely disable a flag, and _not_ repurpose it, using the
`disable_flag` directive. It lets you mark one or more flags as "never use".

For example, if you disable the `-q` flag, then `-q` will no longer be a
built-in flag that decreases the verbosity, but `--quiet` will remain. To
completely disable decreasing the verbosity, disable both `-q` and `--quiet`.

    # Disables -q but leaves --quiet
    disable_flag "-q"

    # Completely disables decreasing verbosity
    disable_flag "-q", "--quiet"

### Disabling Argument Parsing

Normally Toys handles parsing command line arguments for you. This makes
writing tools easier, and also allows Toys to generate documentation
automatically for flags and arguments. However, occasionally you'll not want
Toys to perform any parsing, but just to give you the command line arguments
raw. One common case is if your tool turns around and passes its arguments
verbatim to another subprocess.

To disable argument parsing, use the `disable_argument_parsing` directive. This
directive disables parsing and validation of flags and positional arguments.
(Thus, it is incompatible with specifying any flags or arguments for the tool.)
Instead, you can retrieve the raw arguments using the
[Toys::Tool#args method](https://www.rubydoc.info/gems/toys-core/Toys%2FTool:args).

Here is an example that wraps calls to git:

    tool "my-git" do
      desc "Prints a message, and then calls git normally"
      disable_argument_parsing
      def run
        puts "Calling my-git!"
        Kernel.exec(["git"] + args)
      end
    end

## Toys Administration Using the System Tools

Toys comes with a few built-in tools, including some that let you administer
Toys itself. These tools live in the `system` namespace.

### Getting the Toys Version

You can get the current version of Toys by running:

    toys system version

Note that the same output can be obtained by passing the `--version` flag to
the root tool:

    toys --version

### Upgrading Toys

To update Toys to the latest released version, run:

    toys system update

This will determine the latest version from Rubygems, and update your Toys
installation if it is not already current.

Normall it asks you for confirmation before downloading. To disable interactive
confirmation, pass the `--yes` flag.

A similar effect can of course be obtained simply by `gem install toys`.

## Writing Your Own CLI Using Toys

Toys is not primarily designed to help you write a custom command-line binary,
but you can use it in that fashion. Toys is factored into two gems:
**toys-core**, which includes all the underlying machinery for creating
command-line binaries, and **toys**, which is really just a wrapper that
provides the `toys` binary itself and its built-in commands and behavior. To
write your own command line binary based on the Toys system, just require the
**toys-core** gem and configure your binary the way you want.

Toys-Core is modular and lets you customize much of the behavior of a command
line binary. For example:

*   Toys itself automatically adds a number of flags, such as `--verbose` and
    `--help`, to each tool. Toys-Core lets you customize what flags are
    automatically added for your own command line binary.
*   Toys itself provides a default way to run tools that have no `run` method:
    it assumes such tools are namespaces, and displays the online help screen.
    Toys-Core lets you provide an alternate default run method for your own
    command line binary.
*   Toys itself provides several built-in tools, such as `do`, and `system`.
    Toys-Core lets your own command line binary define its own built-in tools.
*   Toys itself implements a particular search path for user-provided Toys
    files, and looks for specific file and directory names such as `.toys.rb`.
    Toys-Core lets you change the search path, the file/directory names, or
    disable user-provided Toys files altogether for your own command line
    binary. Indeed, most command line binaries do not need user-customizable
    tools, and can ship with only built-in tools.
*   Toys itself has a particular way of displaying online help and displaying
    errors. Toys-Core lets your own command line binary customize these.

For more information, see the
[Toys-Core documentation](https://www.rubydoc.info/gems/toys-core/).
