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
actual behavior of the toys binary by writing *configuration files*.

Toys is a multi-command binary. You may define a collection of commands, called
*tools*, which can be invoked by passing the tool name as an argument to the
`toys` binary. Tools are arranged in a hierarchy; a tool may be a *namespace*
that has *subtools*.

Tools may recognize command line arguments in the form of *flags* and
*positional arguments*. Flags can optionally take *values*, while positional
arguments may be *required* or *optional*.

The configuration of a tool may define *descriptions*, for the tool itself, and
for each command line argument. These descriptions are displayed in the tool's
*online help* screen. Descriptions come in *long* and *short* forms, which
appear in different styles of help.

Toys searches for configuration in specifically-named *configuration files* and
*configuration directories*. It searches for these in the current directory,
and in a *configuration search path*.

Toys provides various features to help you write tools. This includes providing
a *logger* for each tool, *helper modules* that provide common functions a tool
can call, and *templates* which are prefabricated tools you can add to your
configuration.

Finally, Toys provides certain *built-in behavior*, including automatically
providing flags to display help screens and set verbosity. It also includes a
built-in namespace of *system tools* that let you inspect and configure the
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
until it finds a legitimate tool. In this case, the `system` namespace itself
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

Note that a single hyphen by itself `-` is not considered a flag and is treated
as a positional argument.

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

## Understanding Configurations

## Helper Methods and Modules

## The Standard Helpers

## Prefabricated Tools with Templates

## Defining Templates

## Advanced Tool Definition Techniques

## Embedding Toys
