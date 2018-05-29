# @title Toys User Guide

# Toys User Guide

Toys is a command line binary that lets you build your own personal suite of
command line tools using a Ruby DSL. Toys handles argument parsing, error
reporting, logging, help text, and many other details for you. Toys is designed
for software developers, IT specialists, and other power users who want to
write and organize scripts to automate their workflows.

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

Finally, Toys provides certain **built-in behavior**, including automatically
providing flags to display help screens and set verbosity. It also includes a
built-in namespace of **system tools** that let you inspect and configure the
Toys system itself.

## The Toys Command Line

In this section, you will learn how Toys parses its command line, identifies a
tool to run, and interprets flags and other command line arguments.

The general form of the `toys` command line is:

    toys [TOOL...] [FLAGS...] [ARGS...]

### Tools

The *tool name* consists of all the command line arguments until the first
argument that begins with a hyphen (which is interpreted as a *flag*), until
no tool with that name exists (in which case the argument is treated as the
first *positional argument*), or until there are no more arguments.

For example, in the following command:

         |----TOOL----|
    toys system version

The tool name is `system version`. Notice that the tool name may have multiple
words. Tools are arranged hierarchically. In this case, `system` is a
*namespace* for tools related to the Toys system, and `version` is one of its
*subtools*. It prints the current Toys version.

In the following command:

         |TOOL| |ARG|
    toys system blah

There is no subtool `blah` under the `system` namespace, so Toys works backward
until it finds an existing tool. In this case, the `system` namespace itself
does exist, so it is interpreted as the tool, and `blah` is interpreted as an
argument passed to it.

Namespaces such as `system` are themselves tools and can be executed like any
other tool. In the above case, its function is to take the argument `blah`,
note that it has no subtool of that name, and print an error message. Most
commonly, though, you might execute a namespace without arguments:

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

Flags are generally arguments that begin with a hyphen, and are used to set
options for a tool.

Each tool recognizes a specific set of flags. If you pass an unknown flag to a
tool, the tool will generally display an error message.

Toys follows the typical unix conventions for flags: you can provide short
(single-character) flags with a single hyphen, or long flags with a double
hyphen. You can also provide optional values for flags. Following are a few
examples.

Pass a single short flag (for verbose output).

    toys -v

Pass multiple long flags (verbose output, and recursive subtool search).

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
positional arguments. Positional arguments are recognized in order and may be
required or optional.

Each tool recognizes a specific set of positional arguments. If you do not pass
a value for a required argument, or you pass too many arguments, the tool will
generally display an error message.

For example, the `do` tool runs multiple tools in sequence. It recognizes any
number of positional arguments. Those arguments specify which tools to run and
what arguments to pass to them. If, for example, you had a `build` tool and a
`test` tool, you could run them in sequence with:

            |---ARGS---|
    toys do build , test

The arguments `build`, `,`, and `test` are positional arguments to the `do`
tool. (The `do` tool splits them using `,` as the delimiter.)

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

Tools are defined by writing Toys *configuration files*. The simplest form of a
configuration file is a file named `.toys.rb` (note the leading period) in the
current working directory. Such a file may define tools that are available in
the current directory, and for this section we will assume we are writing such
a file. The following section on "Understanding Configurations" will cover the
larger concerns of how configuration files are looked up and how multiple
configurations interact.

### Basic Config Syntax

The format of a Toys configuration file is a Ruby DSL including method calls
and nested blocks. The actual DSL is specified in the
[ConfigDSL class](https://www.rubydoc.info/gems/toys-core/Toys/ConfigDSL).

To create a tool, write a `tool` block, giving the tool a name. Within the
block, set the properties of the tool, including a description, the flags and
arguments recognized by the tool, and the actual functionality of the tool.

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

Each tool may have a short and a long description. The short description is a
generally a single string that is displayed with the tool name at the top of
its help page, or in a subtool list. The long description can include multiple
strings, which are displayed in multiple lines in the "description" section of
the tool's help page. Long descriptions may include blank lines to separate
paragraphs visually.

Each description string/line is word-wrapped by default when displayed. In the
long description above, the first line is a bit longer than 80 characters, and
may be word-wrapped if displayed on an 80-character terminal.

If you need to control the wrapping behavior, pass an array of strings for that
line. Each array element will be considered a unit for wrapping purposes, and
will not be split. The example command in the long description above
illustrates how to prevent a line from being word-wrapped. This is also a
useful technique for preserving spaces and indentation.

For more details, see the reference documentation for
[ConfigDSL#desc](https://www.rubydoc.info/gems/toys-core/Toys%2FConfigDSL:desc)
and
[ConfigDSL#long_desc](https://www.rubydoc.info/gems/toys-core/Toys%2FConfigDSL:long_desc).

### Positional Arguments

Tools may recognize required and optional positional arguments. Each argument
must provide a name, which defines how the argument value is exposed to the
tool at execution time. The above example uses the DSL method
[ConfigDSL#optional_arg](https://www.rubydoc.info/gems/toys-core/Toys%2FConfigDSL:optional_arg)
to declare an optional argument named `:whom`. If the argument is provided on
the command line e.g.

    toys greet ruby

Then the option `:whom` is set to the string `"ruby"`. The value is made
available via the `options` hash in the tools's script. Otherwise, if the
argument is omitted, e.g.

    toys greet

Then the option `:whom` is set to the default value `"world"`.

Arguments may also be **required** which means they must be provided on the
command line; otherwise the tool will report a usage error. You may declare a
required argument using the DSL method
[ConfigDSL#required_arg](https://www.rubydoc.info/gems/toys-core/Toys%2FConfigDSL:required_arg).

When command line arguments are parsed, the required arguments are matched
first, in order, followed by the optional arguments. For example:

    tool "arguments" do
      optional_arg :arg2
      required_arg :arg1
      # ...

If a user runs

    toys arguments foo

Then the required argument `:arg1` will be set to `"foo"`, and the optional
argument `:arg2` will not be set (i.e. it will remain `nil`).

If the user runs:

    toys arguments foo bar

Then `:arg1` is set to `"foo"`, and `:arg2` is set to `"bar"`.

Running the following:

    toys arguments

Will produce a usage error, because no value is set for the required argument
`:arg1`. Similarly, running:

    toys arguments foo bar baz

Will also produce an error, since the tool does not provide an argument to
match `"baz"`.

You can also provide an "argument" to match all remaining unmatched arguments
at the end, using the DSL method
[ConfigDSL#remaining_args](https://www.rubydoc.info/gems/toys-core/Toys%2FConfigDSL:remaining_args). For example:

    tool "arguments" do
      optional_arg :arg2
      required_arg :arg1
      remaining_args :arg3
      # ...

Now, running:

    toys arguments foo bar baz bey

Sets the following option data:

    {arg1: "foo", arg2: "bar", arg3: ["baz", "bey"]}

Positional arguments may also have short and long descriptions, which are
displayed in online help.

### Flags

Tools may also recognize flags on the command line. In our "greet" example, we
declared a flag named `:shout`:

    flag :shout, "-s", "--shout", desc: "Greet loudly."

(guid is still incomplete)

### The Execution Script

### Namespaces

## Understanding Configurations

## Helper Methods and Modules

### The Standard Helpers

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

### Includes

### Controlling Built-in Flags

## The System Tools

## Embedding Toys
