# @title Toys User Guide

# Toys User Guide

Toys is a command line binary that lets you build your own personal suite of
command line tools using a Ruby DSL. Toys handles argument parsing, error
reporting, logging, help text, and many other details for you. Toys is designed
for software developers, IT specialists, and other power users who want to
write and organize scripts to automate their workflows.

Unlike most command line frameworks, Toys is *not primarily* designed to help
you build and ship a custom command line binary written in Ruby. Rather, it
provides a single multi-command binary called `toys`, and you provide the
commands, called "tools" by writing config files. (You can, however, use the
separate **toys-core** library to build a new command line binary.)

This user's guide covers everything you need to know to use Toys effectively.

## Conceptual overview

Toys is a command line *framework*. It provides a binary called `toys` along
with basic functions such as argument parsing and online help. You provide the
actual behavior of the toys binary by writing **configuration files**.

Toys is a multi-command binary. You may define a collection of commands, called
**tools**, which can be invoked by passing the tool name as an argument to the
`toys` binary. Tools are arranged in a hierarchy; a tool may be a **namespace**
that has *subtools*.

Tools may recognize command line arguments in the form of **flags** and
**positional arguments**. Flags can optionally take **values**, while
positional arguments may be **required** or **optional**.

The configuration of a tool may define **descriptions**, for the tool itself,
and for each command line argument. These descriptions are displayed in the
tool's **online help** screen. Descriptions come in **long** and **short**
forms, which appear in different styles of help.

Toys searches for configuration in specifically-named **configuration files**
and **configuration directories**. It searches for these in the current
directory, its ancestors, and in a **configuration search path**.

Toys provides various features to help you write tools. This includes providing
a **logger** for each tool, **helper modules** that provide common functions a
tool can call, and **templates** which are prefabricated tools you can add to
your configuration.

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
itself does exist, so Toys runs *it* as the tool, and passes it `blah` as an
argument.

Namespaces such as `system` are themselves tools and can be executed like any
other tool. In the above case, it takes the argument `blah`, determines that it
has no subtool of that name, and print an error message. Most commonly, though,
you might execute a namespace without arguments:

    toys system

This displays the *online help screen* for the `system` namespace, which
includes a list of all its subtools and what they do.

It is also legitimate for the tool name to be empty. This invokes the "root"
tool, the toplevel namespace:

    toys

Like any namespace, the root tool displays its help screen, including the list
of its subtools.

One last example:

    toys blah

If there is no tool called `blah` in the toplevel namespace, then once again,
`blah` is interpreted as an argument to the root tool. The root tool responds
by printing an error message that the `blah` tool does not exist.

### Flags

**Flags** are generally arguments that begin with a hyphen, and are used to set
options for a tool.

Each tool recognizes a specific set of flags. If you pass an unknown flag to a
tool, the tool will generally display an error message.

Toys follows the typical unix conventions for flags: you can provide short
(single-character) flags with a single hyphen, or long flags with a double
hyphen. You can also provide optional **values** for flags. Following are a few
examples.

Pass a single short flag (for verbose output).

    toys -v

Pass multiple long flags (for verbose output and recursive subtool search).

    toys --verbose --recursive

You can combine short flags. This does the same as the previous example.

    toys -rv

Pass a value using a long flag. This searches subtools for the keyword `build`.

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
message that no subtool named `--recursive` exists.)

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

For example, the `do` tool runs multiple tools in sequence. It recognizes any
number of positional arguments. Those arguments specify which tools to run and
what arguments to pass to them. If, for example, you had a `build` tool and a
`test` tool, you could run them in sequence with:

            |---ARGS---|
    toys do build , test

The three arguments `build`, `,`, and `test` are positional arguments to the
`do` tool. (The `do` tool splits them using `,` as the delimiter.)

Here is a more complex example illustrating the interaction between flags and
positional arguments. Suppose we want to use `do` to display the help screens
for the root tool and the system tool in sequence. That is, we want to run
`toys --help` and `toys system --help` in sequence. We might start by trying:

    toys do --help , system --help

However, this simply displays the help for the `do` tool itself, because the
first `--help` is interpreted as a flag for `do` instead of a positional
argument specifying the first tool for `do` to run. We need to force `do` to
treat all its arguments as positional, and we can do that by starting with `--`
like so:

               |--------ARGS--------|
    toys do -- --help , system --help

## Defining Tools

In this section, you will learn how to define tools by writing a Toys
**configuration file**.

A file named `.toys.rb` (note the leading period) in the current working
directory defines tools available in that directory and its subdirectories. We
will cover how to write tools, including specifying the functionality of the
tool, the flags and arguments it takes, and how its description appears in the
help screen.

### Basic Config Syntax

The format of a Toys configuration file is a Ruby DSL including directives,
methods, and nested blocks. The actual DSL is specified in the
[Toys::DSL::Tool class](https://www.rubydoc.info/gems/toys-core/Toys/DSL/Tool).

To create a tool, write a `tool` block, giving the tool a name. Within the
block, use directives to set the properties of the tool, including descriptions
and the flags and arguments recognized by the tool. The actual functionality of
the tool is set by defining a `run` method.

Consider the following example:

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
        greeting = "Hello, #{option(:whom)}!"
        greeting.upcase! if option(:shout)
        puts greeting
      end
    end

Its results should be mostly self-evident. We'll take a look at some of the
details below.

### Descriptions

Each tool may have a **short description** and/or a **long description**. The
short description is a generally a single string that is displayed with the
tool name, at the top of its help page or in a subtool list. The long
description typically includes multiple strings, which are displayed in
multiple lines in the "description" section of the tool's help page. Long
descriptions may include blank lines to separate paragraphs visually.

Each description string/line is word-wrapped by default when displayed. In the
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

Then the option `:whom` is set to the string `"ruby"`. The value is made
available via the `options` hash in the tools's script. Otherwise, if the
argument is omitted, e.g.

    toys greet

Then the option `:whom` is set to the default value `"world"`.

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

Will also produce an error, since the tool does not provide an argument to
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

Whereas your tool can include any number of `required_arg` and `optional_arg`
directives, declaring any number of required and optional arguments, it can
have only at most a single `remaining_args` directive.

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

See the above section on Descriptions for more information on how descriptions
are rendered and word wrapped.

Long descriptions may be unwieldly to write as a hash argument in this way. So
Toys provides an alternate syntax for defining arguments using a block.

    required_arg :arg do
      desc "This is a short description for the arg"
      long_desc "Long desc can be set as multiple lines together,",
                "like this second line."
      long_desc "Or you can call long_desc again to add more lines."
    end

For detailed info on configuring an argument using a block, see the
[Toys::DSL::Arg class](https://www.rubydoc.info/gems/toys-core/Toys/DSL/Arg).

#### Acceptors

Finally, positional arguments may use **acceptors** to define how to validate
arguments and convert them to Ruby objects for your tool to consume. By
default, Toys will accept an argument string in any form, and expose it to your
tool as a raw string. However, you may provide an acceptor to change this
behavior.

Acceptors are part of the OptionParser interface, and are described under the
[type coercion](http://ruby-doc.org/stdlib/libdoc/optparse/rdoc/OptionParser.html#class-OptionParser-label-Type+Coercion)
section. For example, you can provide the `Integer` class as an acceptor, which
will validate that the argument is a well-formed integer, and convert it to an
integer during parsing:

    tool "args-demo" do
      required_arg :age, accept: Integer
      def run
        option(:age)  # This is an integer
        ...

If you pass a non-integer for this argument, Toys will report a usage error.

You may use any of the ready-to-use coercion types provided by OptionParser,
including the special types such as
[OptionParser::DecimalInteger](http://ruby-doc.org/stdlib/libdoc/optparse/rdoc/OptionParser.html#DecimalInteger)
and
[OptionParser::OctalInteger](http://ruby-doc.org/stdlib/libdoc/optparse/rdoc/OptionParser.html#OctalInteger).

You may also create custom acceptors. See the section below on Custom Acceptors
for more information.

### Flags

Tools may also recognize **flags** on the command line. In our "greet" example,
we declared a flag named `:shout`:

    flag :shout, "-s", "--shout", desc: "Greet loudly."

Like a positional argument, a flag sets an option based on the command line
arguments passed to the tool. In the case above, the `:shout` option is set to
`true` if either `-s` or `--shout` is provided on the command line; otherwise
it is set to `false`. Any number of short or long flags can be declared; they
will be synonyms and have the same effect.

#### Flag Types

Toys recognizes the same syntax used by the standard OptionParser library. This
means you can also declare a flag that can be both set and unset:

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
    flag :whom, "-wVALUE"
    flag :whom, "-w VALUE"

Note that if you define multiple flags together, they will all be coerced to
the same "type". That is, if one takes a value, they all will implicitly take
a value. (This is the same behavior as OptionParser.) In this example:

    flag :whom, "-w", "--whom=VALUE"

The `-w` flag will also implicitly take a value, because it is defined as an
alias with another flag that takes a value.

Note also that Toys will raise an error if those flags are incompatible. For
example:

    flag :whom, "-w[VALUE]", "--whom=VALUE"

Raises an error because one flag's value is optional while the other is
required. (Again, this is consistent with OptionParser's behavior.)

#### Custom Acceptors

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
        option(:age)  # This is an integer
        ...

If you pass a non-integer for this flag value, Toys will report a usage error.

You may use any of the ready-to-use coercion types provided by OptionParser,
including the special types such as
[OptionParser::DecimalInteger](http://ruby-doc.org/stdlib/libdoc/optparse/rdoc/OptionParser.html#DecimalInteger)
and
[OptionParser::OctalInteger](http://ruby-doc.org/stdlib/libdoc/optparse/rdoc/OptionParser.html#OctalInteger).

You may also create custom acceptors. See the section below on Custom Acceptors
for more information.

#### Defaults and Handlers

Currently, flags are always optional and a flag can appear in a command line
zero, one, or any number of times. If a flag is not passed in the command line
arguments for a tool, by default its corresponding option value will be `nil`.

You may change this by providing a default value for a flag:

    flag :age, accept: Integer, default: 21

If you pass a flag multiple times on the command line, by default the last
appearance of the flag will take effect. That is, for the flag:

    flag :shout, "--[no-]shout"

If you pass `--shout --no-shout`, then the value of the `:shout` option will be
`false`. In other words, a flag *sets* its option value, replacing any previous
value. You may change this behavior also, by providing a **handler**.

A handler is a proc that governs what a flag does to its option value. It takes
two arguments, the new value given, and the previously set value (which might
be the default value if this is the first appearance of the flag), and returns
the new value that should be set. So effectively, the default behavior is
equivalent to a handler of `proc { | val, _prev| val }`.

For example, most tools automatically get a "--verbose" flag. This flag may
appear any number of times, and each appearance increases the verbosity. The
value of this verbosity is an integer. This flag is actually implemented by
Toys, as follows:

    flag Toys::Tool::Keys::VERBOSITY, "-v", "--verbose",
         default: 0,
         handler: proc { |_val, prev| prev + 1 }

Similarly, the "--quiet" flag, which decreases the verbosity, is implemented
as follows:

    flag Toys::Tool::Keys::VERBOSITY, "-q", "--quiet",
         default: 0,
         handler: proc { |_val, prev| prev - 1 }

Note that both flags affect the same option value, `VERBOSITY`. The first
increments it each time it appears, and the second decrements it. A tool can
query this option and get an integer telling the requested verbosity level, as
you will see below in the section on execution environment.

#### Descriptions and the Flags DSL

Flags may also have short and long descriptions, which are displayed in online
help. Set descriptions via the `desc:` and `long_desc:` arguments to the flag
directive. The `desc:` argument takes a single string description, while the
`long_desc:` argument takes an array of strings. Here is an example:

    flag :my_flag, "--my-flag",
         desc: "This is a short description for the arg",
         long_desc: ["Long descriptions may have multiple lines.",
                     "This is the second line."]

See the above section on Descriptions for more information on how descriptions
are rendered and word wrapped.

Long descriptions may be unwieldly to write as a hash argument in this way. So
Toys provides an alternate syntax for defining flags using a block.

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
the configuration, and then it will attempt to execute it by calling the `run`
method. Normally, you should define this method in each of your tools.

If you do not define the `run` method for a tool, Toys provides a default
implementation that displays the tool's help screen. This is typically used for
namespaces, as we shall see below. Most tools, however, should define `run`.

Let's revisit the "greet" example we covered earlier.

    tool "greet" do
      optional_arg :whom, default: "world"
      flag :shout, "-s", "--shout"

      def run
        greeting = "Hello, #{option(:whom)}!"
        greeting.upcase! if option(:shout)
        puts greeting
      end
    end

Note how the `run` method uses the
[Toys::Tool#option](https://www.rubydoc.info/gems/toys-core/Toys%2FTool:option)
method to access values that were assigned by flags or positional arguments.
Note also that you can produce output or interact with the console using the
normal Ruby `$stdout`, `$stderr`, and `$stdin` streams.

If a tool's `run` method finishes normally, Toys will exit with a result code
of 0, indicating success. You may exit immediately and/or provide a nonzero
result using the
[Toys::Tool#exit](https://www.rubydoc.info/gems/toys-core/Toys%2FTool:exit)
method:

    def run
      puts "Exiting with an error..."
      exit(1)
      puts "Will never get here."
    end

If your `run` method raises an exception, Toys will display the exception and
exit with a nonzero code.

Finally, you may also define any additional methods you choose. These are
available to be called by your `run` method, and can be used to decompose your
tool implementation.

This should be enough to get you started implementing tools. A variety of
additional features are available for your tool implementation and will be
discussed further below. But first we will cover a few important topics.

### Namespaces and Subtools

Like many command line frameworks, Toys supports **subtools**. You may, for
example create a tool called "test" that runs your tests for a particular
project, but you might also want "test unit" and "test integration" tools to
run specific subsets of the test suite. One way to do this, of course, is for
the "test" tool to parse "unit" and "integration" as arguments. However, you
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

Notice in this case, the "test" tool has no `run` method. This is a common
pattern: "test" is just a "container" for tools, a way of organizing your
tools. In Toys terminology, it is called a **namespace**. But it is still a
tool, and it can still be run:

    toys test

As discussed earlier, Toys provides a default implementation that displays the
help screen, which includes a list of the subtools and their descriptions. In
particular, the "root" tool is also normally a namespace. If you just run Toys
with no arguments:

    toys

The overall help screen for Toys will be displayed.

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

Toys allows subtools to be nested arbitrarily deep. Although in practice, more
than two or three levels of hierarchy can be confusing to use.

## Understanding Configurations

Commands understood by Toys are defined in configuration files. We covered the
basic syntax for configuration files in the above section on defining tools. In
this section, we will take a deeper look at configuration, including:

* Defining subtools in their own file
* Global and local configurations
* The `TOYS_PATH`
* Overriding tools
* Loading config files from other config files

### Configuration files and directories



### The Config Path



### Loading Files



## Helpers



### The Standard Helpers



### Defining Helpers



### Constants



## The Execution Environment



### Built-in Context



### Logging and Verbosity



### Running Tools from Tools



### Executing Subprocesses



### Formatting Output



## Prefabricated Tools with Templates



### Defining Templates



## Advanced Tool Definition Techniques



### Aliases



### Custom Acceptors



### Controlling Built-in Flags



## Toys Administration using the System Tools



## Embedding Toys
