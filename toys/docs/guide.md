<!--
# @title Toys User Guide
-->

# Toys User Guide

Toys is a configurable command line tool. Write commands in Ruby using a simple
DSL, and Toys will provide the command line executable and take care of all the
details such as argument parsing, online help, and error reporting.

Toys is designed for software developers, IT professionals, and other power
users who want to write and organize scripts to automate their workflows. It
can also be used as a Rake replacement, providing a more natural command line
interface for your project's build tasks.

Unlike most command line frameworks, Toys is *not primarily* designed to help
you build and ship a custom command line executable written in Ruby. Rather, it
provides a single executable called `toys`. You define the commands recognized
by the Toys executable by writing configuration files. (You can, however, build
your own custom command line executable using the related **toys-core**
library.)

If this is your first time using Toys, we recommend starting with the
[README](https://dazuma.github.io/toys/gems/toys/latest), which includes a
tutorial that introduces how to install Toys, write and execute tools, and even
use Toys to replace Rake. The tutorial will likely give you enough information
to start using Toys effectively.

This user's guide is also structured like an extended tutorial, but it is much
longer and covers all the features of Toys in much more depth. Read it when
you're ready to unlock all the capabilities of Toys to create sophisticated
command line tools.

## Conceptual overview

Toys is a command line *framework*. It provides an executable called `toys`
with basic functions such as argument parsing and online help. You provide the
actual behavior of the Toys executable by writing **Toys files**.

Toys is a multi-command executable. You may define any number of commands,
called **tools**, which can be invoked by passing the tool name as an argument
to the `toys` executable. Tools are arranged in a hierarchy; you may define
**namespaces** that have **subtools**.

Tools may recognize command line arguments in the form of **flags** and
**positional arguments**. Flags can optionally take **values**, while
positional arguments may be **required** or **optional**. Flags may be
organized into **flag groups** which support different kinds of constraints on
which flags are required.

The configuration of a tool may include **descriptions**, for the tool itself,
and for each command line argument. These descriptions are displayed in the
tool's **online help** screen. Descriptions come in **long** and **short**
forms, which appear in different styles of help.

Toys searches for tools in specifically-named **Toys files** and **Toys
directories**. It searches for these in the current directory, in its
ancestors, and in the Toys **search path**.

Toys provides various features to help you write tools. This includes providing
a **logger** for each tool, **mixins** that provide common functions a tool can
call (such as to control subprocesses and style output), and **templates**
which are prefabricated tools that you can configure for your needs.

Finally, Toys provides useful **built-in behavior**, including automatically
providing flags to display help screens and set verbosity. It also includes a
built-in namespace of **system tools** that let you inspect and configure the
Toys system itself.

## The Toys command line

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
    $ toys system version

The tool name is `system version`. Notice that the tool name may have multiple
words. Tools are arranged hierarchically. In this case, `system` is a
**namespace** for tools related to the Toys system, and `version` is one of its
**subtools**. It prints the current Toys version.

The words in a tool name can be delimited with spaces as shown above, or
alternately periods or colons. The following commands also invoke the tool
`system version`:

    $ toys system.version
    $ toys system:version

In the following command:

           |TOOL| |ARG|
    $ toys system frodo

There is no subtool `frodo` under the `system` namespace, so Toys works
backward until it finds an existing tool. In this case, the `system` namespace
itself does exist, so Toys runs *it* as the tool, and passes it `frodo` as an
argument.

Namespaces such as `system` are themselves tools and can be executed like any
other tool. In the above case, it takes the argument `frodo`, determines it has
no subtool of that name, and prints an error message. More commonly, though,
you might execute a namespace without arguments:

    $ toys system

This displays the **online help screen** for the `system` namespace, which
includes a list of all its subtools and what they do.

It is also legitimate for the tool name to be empty. This invokes the **root
tool**, the toplevel namespace:

    $ toys

Like any namespace, invoking the root tool displays its help screen, including
showing the list of all its subtools.

One last example:

    $ toys frodo

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
with a single hyphen, or long flags with a double hyphen. Some flags can also
take **values**. Following are a few examples.

Here we pass a single short flag (for verbose output).

    $ toys system -v

Here we pass multiple long flags (for verbose output and recursive subtool
search).

    $ toys system --verbose --recursive

You can combine short flags. The following passes both the `-v` and `-r` flags
(i.e. it has the same effect as the previous example.)

    $ toys system -vr

Long flags can be abbreviated, as long as the abbreviation is not ambiguous.
For example, there is only one flag (`--recursive`) beginning with the string
`--rec`, so you can use the shortened form.

    $ toys --rec

However, there are two flags (`--version` and `--verbose`) beginning with
`--ver`, so it cannot be used as an abbreviation. This will cause an error:

    $ toys --ver

Some flags take values. The root tool supports the `--search` flag to search
for tools that have the given keyword.

    $ toys --search=build
    $ toys --search build

The short form of the search flag `-s` also takes a value.

    $ toys -s build
    $ toys -sbuild

If a double hyphen `--` appears by itself in the arguments, it disables flag
parsing from that point. Any further arguments are treated as positional
arguments, even if they begin with hyphens. For example:

           |--FLAG--|   |---ARG---|
    $ toys --verbose -- --recursive

That will cause `--recursive` to be treated as a positional argument. (In this
case, as we saw earlier, the root tool will respond by printing an error
message that no tool named `--recursive` exists.)

Note that a single hyphen by itself `-` is not considered a flag, nor does it
disable flag parsing. It is treated as a normal positional argument.

#### Standard flags

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

*   `--all` which displays all subtools, including
    [hidden subtools](#Hidden_tools) and namespaces.
*   `--no-recursive` which displays only immediate subtools, instead of the
    default behavior of showing all subtools recursively.
*   `--search=TERM` which displays only subtools whose name or description
    contain the specified search term.
*   `--tools` which displays just the list of subtools rather than the entire
    help screen.

Finally, the root tool also supports:

*   `--version` which displays the current Toys version.

### Positional arguments

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
    $ toys do build , test

The three arguments `build` and `,` and `test` are positional arguments to the
`do` tool. (The `do` tool uses `,` to delimit the tools that it should run.)

Most tools allow flags and positional arguments to be interspersed. A flag will
be recognized even if it appears after some of the positional arguments.

However, this approach would not work for the `do` tool because its common case
is to pass flags down to the steps it runs. (That is, `do` wants most arguments
to be treated as positional even if they look like flags.) So `do` stops
recognizing flags once it encounters its first positional argument. That is,
you could do this:

              |------------ARGS-----------|
    $ toys do build --staging , test --help

Each tool can choose which behavior it will support, whether or not to enforce
[flags before positional args](#Enforcing_flags_before_args).

You can also, of course, stop recognizing flags on the command line by passing
`--` as an argument.

### Tab completion

If you are using the Bash shell, Toys provides custom tab completion. See
[this section](#Installing_tab_completion_for_Bash) for instructions on
installing tab completion.

Toys will complete tool and subtool names, flags, values passed to flags, and
positional argument values, and it will respect the current context. For
example, if you type:

    $ toys <TAB><TAB>

The tab completion will show you a list of reasonable things that could appear
next, including the defined tool names (such as `system` and `do`) as well as
all the flags supported by the root tool (such as `--help` and `-v`). And of
course, if you start typing something, tab completion will limit the display to
matching completions. The following displays only flags, i.e. completions that
begin with a hyphen:

    $ toys -<TAB><TAB>

And if you type the following:

    $ toys sys<TAB>

It is likely only one tool name starts with `sys`, so completion will
automatically type the rest of `system` for you.

The tab completion for Toys also supports values passed to flags and positional
args. As we shall see later, when you define a flag or a positional argument,
you can specify how completions are computed.

**Note:** Because of the highly dynamic nature of Toys in which tools, flags,
and arguments can be highly customized, the completion implementation actually
requires *executing Toys* so it can analyze your tool configurations. This
unfortunately means paying some upfront latency as the Ruby interpreter starts
up. So you can expect a slight pause when evaluating tab completion for Toys,
at least in comparison with most other tab completions.

## Defining tools

So far we've been experimenting only with the built-in tools provided by Toys.
In this section, you will learn how to define tools by writing a **Toys file**.
We will cover how to write tools, including specifying the functionality of the
tool, the flags and arguments it takes, and how its description appears in the
help screen.

### Basic Toys syntax

A file named `.toys.rb` (note the leading period) in the current working
directory is called a **Toys file**. It defines tools available in that
directory and its subdirectories.

The format of a Toys file is a Ruby DSL that includes directives, methods, and
nested blocks. The actual DSL is specified in the
[Toys::DSL::Tool class](https://dazuma.github.io/toys/gems/toys-core/latest/Toys/DSL/Tool).

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
        greeting = greeting.upcase if shout
        puts greeting
      end
    end

Its results should be mostly self-evident. But let's unpack a few details.

### Tool descriptions

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
[Toys::DSL::Tool#desc](https://dazuma.github.io/toys/gems/toys-core/latest/Toys/DSL/Tool#desc-instance_method)
and
[Toys::DSL::Tool#long_desc](https://dazuma.github.io/toys/gems/toys-core/latest/Toys/DSL/Tool#long_desc-instance_method).

### Positional arguments

Tools may recognize any number of **positional arguments**. Each argument must
have a name, which is a key that the tool can use to obtain the argument's
value at execution time. Arguments may also have various properties controlling
how values are validated and expressed.

The above example uses the directive
[Toys::DSL::Tool#optional_arg](https://dazuma.github.io/toys/gems/toys-core/latest/Toys/DSL/Tool#optional_arg-instance_method)
to declare an **optional argument** named `:whom`. If the argument is provided
on the command line e.g.

    $ toys greet ruby
    Hello, ruby!

Then the option `:whom` is set to the string `"ruby"`. Otherwise, if the
argument is omitted, e.g.

    $ toys greet
    Hello, world!

Then the option `:whom` is set to the default value `"world"`.

If the option name is a valid method name, Toys will provide a method that you
can use to retrieve the value. In the above example, we retrieve the value for
the option `:whom` by calling the method `whom`. If the option name cannot be
made into a method, you can retrieve the value by calling
[Toys::Context#get](https://dazuma.github.io/toys/gems/toys-core/latest/Toys/Context#get-instance_method).

An argument may also be **required**, which means it must be provided on the
command line; otherwise the tool will report a usage error. You may declare a
required argument using the directive
[Toys::DSL::Tool#required_arg](https://dazuma.github.io/toys/gems/toys-core/latest/Toys/DSL/Tool#required_arg-instance_method).

#### Parsing required and optional arguments

When command line arguments are parsed, the required arguments are matched
first, in order, followed by the optional arguments. For example:

    tool "args-demo" do
      optional_arg :arg2
      required_arg :arg1

      def run
        puts "options data is #{options.inspect}"
      end
    end

If a user runs

    $ toys args-demo foo
    Options data is {arg1: "foo", arg2: nil}

Then the required argument `:arg1` will be set to `"foo"`, and the optional
argument `:arg2` will not be set (i.e. it will remain `nil`).

If the user runs:

    $ toys args-demo foo bar
    Options data is {arg1: "foo", arg2: "bar"}

Then `:arg1` is set to `"foo"`, and `:arg2` is set to `"bar"`.

Running the following:

    $ toys args-demo

Will produce a usage error, because no value is set for the required argument
`:arg1`. Similarly, running:

    $ toys args-demo foo bar baz

Will also produce an error, since the tool does not define an argument to
match `"baz"`.

Optional arguments may declare a default value to be used if the argument is
not provided on the command line. For example:

    tool "args-demo" do
      required_arg :arg1
      optional_arg :arg2, default: "the-default"

      def run
        puts "options data is #{options.inspect}"
      end
    end

Now running the following:

    $ toys args-demo foo
    Options data is {arg1: "foo", arg2: "the-default"}

Will set the required argument to `"foo"` as usual, and the optional argument,
because it is not provided, will default to `"the-default"` instead of `nil`.

#### Remaining arguments

Normally, unmatched arguments will result in an error message. However, you can
provide an "argument" to match all **remaining** unmatched arguments at the
end, using the directive
[Toys::DSL::Tool#remaining_args](https://dazuma.github.io/toys/gems/toys-core/latest/Toys/DSL/Tool#remaining_args-instance_method).
For example:

    tool "args-demo" do
      required_arg :arg1
      optional_arg :arg2
      remaining_args :arg3

      def run
        puts "Options data is #{options.inspect}"
      end
    end

Now, we can see how the remaining arguments (if any) are collected by `:arg3`:

    $ toys args-demo foo bar baz qux
    Options data is {arg1: "foo", arg2: "bar", arg3: ["baz", "qux"]}

    $ toys args-demo foo
    Options data is {arg1: "foo", arg2: nil, arg3: []}

Tools can include any number of `required_arg` and `optional_arg` directives,
declaring any number of required and optional arguments. But tools can have at
most only one `remaining_args` directive.

#### Descriptions and the args DSL

Positional arguments may also have short and long descriptions, which are
displayed in online help. Set descriptions via the `desc:` and `long_desc:`
arguments to the argument directive. The `desc:` argument takes a single string
description, while the `long_desc:` argument takes an array of strings. Here is
an example:

    required_arg :arg,
                 desc: "This is a short description for the arg",
                 long_desc: ["Long descriptions may have multiple lines.",
                             "This is the second line."]

See the [above section on Descriptions](#Tool_descriptions) for more
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
[Toys::DSL::PositionalArg class](https://dazuma.github.io/toys/gems/toys-core/latest/Toys/DSL/PositionalArg).

#### Argument acceptors

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
      end
    end

If you pass a non-integer for this argument, Toys will report a usage error.

You may use any of the ready-to-use coercion types provided by OptionParser,
including the special types such as
[OptionParser::DecimalInteger](http://ruby-doc.org/stdlib/libdoc/optparse/rdoc/OptionParser.html#DecimalInteger)
and
[OptionParser::OctalInteger](http://ruby-doc.org/stdlib/libdoc/optparse/rdoc/OptionParser.html#OctalInteger).

You may also create **custom acceptors**. See the
[section below on Custom Acceptors](#Custom_acceptors) for more information.

#### Argument completions

Shell tab completion supports positional arguments, and arguments can be
configured to present a set of completion candidates for themselves.

By default, an argument does not provide any completions for itself. To change
that, set the `completion` option. Currently there are three ways to set the
completion:

*   Provide a static set of possible values, as an array of strings.
*   Specify that values should be paths in the file system by setting the
    symbol `:file_system`.
*   Provide a `Proc` that returns possible values.

The following are two example arguments, one that supports a static set of
completions and the other that supports file paths.

    required_arg :language, complete: ["ruby", "elixir", "rust"]
    required_arg :path, complete: :file_system

Completions are somewhat related to acceptors, and it is a common pattern to
set both in concert. But they perform distinct functions. Acceptors affect
argument parsing, whereas completions affect tab completion in the shell.

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
[Toys::Context#get](https://dazuma.github.io/toys/gems/toys-core/latest/Toys/Context#get-instance_method).

#### Flag types

Toys recognizes the same syntax used by the standard OptionParser library. This
means you can also declare a flag that can be set either to true or false:

    flag :shout, "--[no-]shout"

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

#### Inferred flags

If you do not provide any actual flags, Toys will attempt to infer one from the
name of the option. A one-character name will yield a short flag, and a longer
name a long flag. Hence, the following two definitions are equivalent:

    flag :shout
    flag :shout, "--shout"

And the following two are equivalent:

    flag :S
    flag :S, "-S"

Inferred flags will convert underscores to hyphens. So the following two
definitions are also equivalent:

    flag :call_out
    flag :call_out, "--call-out"

#### Handling optional values

There are some subtleties in how the Ruby OptionParser library treats flags
with optional values. Although Toys does not use OptionParser interally, it
does, for the most part, replicate OptionParser's behavior. It is thus
important to understand that behavior if you use optional values.

First, if a flag has an optional value that is not provided on the command
line, then the option is set to `true`, as if it were a normal boolean flag
that didn't take a value. Consider this example:

    tool "flags-demo" do
      flag :output, "--output [DIRECTORY]", default: "."
      def run
        puts "output is #{output.inspect}"
      end
    end

If a user executes this without passing the `--output` flag, the default will
be printed as we expect.

    $ toys flags-demo
    output is "."

If a user executes this and provides a value for `--output`, it will show up:

    $ toys flags-demo --output /etc
    output is "/etc"

If a user provides `--output` but omits the value, it displays `true`:

    $ toys flags-demo --output
    output is true

Second, if the following argument looks like a flag (i.e. it begins with a
hyphen), it is not treated as an optional value. In this example, the argument
`--verbose` is not treated as the value of `--output` but as a separate flag.
(If `--output` had a *required* value, then `--verbose` would have been treated
as the value.)

    $ toys flags-demo --output --verbose
    output is true

Finally, there is an important difference between the syntax
`"--output [DIRECTORY]"` and `"--output=[DIRECTORY]"`. In the former case, the
following argument (as long as it doesn't look like a flag) will be treated as
the value. In the latter case, however, the following argument is *never*
treated as the value. In that latter case, you *must* use the equals sign
syntax to provide a value.

To illustrate, consider two flags with optional values, one using space and the
other using equals.

    tool "flags-demo-space" do
      flag :output, "--output [DIRECTORY]", default: "."
      set_remaining_args :remaining
      def run
        puts "output is #{output.inspect}"
      end
    end
    tool "flags-demo-equals" do
      flag :output, "--output=[DIRECTORY]", default: "."
      set_remaining_args :remaining
      def run
        puts "output is #{output.inspect}"
      end
    end

Here is the behavior:

    $ toys flags-demo-space --output=/etc
    output is "/etc"
    $ toys flags-demo-space --output /etc
    output is "/etc"
    $ toys flags-demo-equals --output=/etc
    output is "/etc"
    $ toys flags-demo-equals --output /etc
    output is true

#### Flag acceptors

Flags may use **acceptors** to define how to validate values and convert them
to Ruby objects for your tool to consume. By default, Toys will accept a flag
value string in any form, and expose it to your tool as a raw string. However,
you may provide an acceptor to change this behavior.

Acceptors are part of the OptionParser interface, and are described under the
[type coercion](http://ruby-doc.org/stdlib/libdoc/optparse/rdoc/OptionParser.html#class-OptionParser-label-Type+Coercion)
section. For example, you can provide the `Integer` class as an acceptor, which
will validate that the argument is a well-formed integer, and convert it to an
integer during parsing:

    tool "flags-demo" do
      flag :age, accept: Integer
      def run
        puts "Next year I will be #{age + 1}"  # Age is an integer
      end
    end

If you pass a non-integer for this flag value, Toys will report a usage error.

You may use any of the ready-to-use coercion types provided by OptionParser,
including the special types such as
[OptionParser::DecimalInteger](http://ruby-doc.org/stdlib/libdoc/optparse/rdoc/OptionParser.html#DecimalInteger)
and
[OptionParser::OctalInteger](http://ruby-doc.org/stdlib/libdoc/optparse/rdoc/OptionParser.html#OctalInteger).

You may also create **custom acceptors**. See the
[section below on Custom Acceptors](#Custom_acceptors) for more information.

#### Defaults and handlers

Flags are usually optional; a flag can appear in a command line zero, one, or
any number of times.

If a flag is not passed in the command line arguments for a tool, by default
its corresponding option value will be `nil`. You may change this by providing
a default value for a flag:

    flag :age, accept: Integer, default: 21

If you pass a flag multiple times on the command line, by default the *last*
appearance of the flag will take effect. That is, suppose you define this flag:

    flag :shout, "--[no-]shout"

Now if you pass `--shout --no-shout`, then the value of the `:shout` option
will be `false`, i.e. the last value set on the command line. This is because a
flag normally *sets* its option value, replacing any previously set value.

You can, however, change this behavior by providing a **handler**. A handler is
a Ruby Proc that defines what a flag does to its option value. It takes two
arguments, the new value given, and the previously set value (which might be
the default value if this is the first appearance of the flag), and returns the
new value that should be set.

Effectively, the default behavior (setting the value and ignoring the previous
value) is equivalent to the following handler:

    flag :shout, "--[no-]shout", handler: proc { | val, _prev| val }

Toys gives the default handler the special name `:set`. So the above is also
equivalent to:

    flag :shout, "--[no-]shout", handler: :set

The `--verbose` flag, provided automatically by Toys for most tools, shows an
example of an alternate handler. Verbosity is represented by an integer value,
defaulting to 0. The `--verbose` flag may appear any number of times, and
*each* appearance increases the verbosity. Its implementation is internal to
Toys, but looks something like this:

    flag Toys::Context::Key::VERBOSITY, "-v", "--verbose",
         default: 0,
         handler: proc { |_val, prev| prev + 1 }

Similarly, the "--quiet" flag, which decreases the verbosity, is implemented
like this:

    flag Toys::Context::Key::VERBOSITY, "-q", "--quiet",
         default: 0,
         handler: proc { |_val, prev| prev - 1 }

Note that both flags affect the same option name, `VERBOSITY`. The first
increments it each time it appears, and the second decrements it. A tool can
query this option and get an integer telling the requested verbosity level, as
you will see [below](#Logging_and_verbosity).

Toys provides a few built-in handlers that can be specified by name. We already
discussed the default handler that can be specified by its name `:set` or by
simply omitting the `handler:` option. Another named handler is `:push`. This
handler is intended for flags that take values and can be provided more than
once. The final value is then an array of values.

In the following example, an invocation can provide any number of `--include`
flags, and the `:include` option will be set to an array of the given paths.

    flag :include, "-I", "--include PATH", default: [], handler: :push

The `:push` handler is equivalent to
`proc { |val, array| array.nil? ? [val] : array << val }`.

#### Descriptions and the flags DSL

Flags may also have short and long descriptions, which are displayed in online
help. Set descriptions via the `desc:` and `long_desc:` arguments to the flag
directive. The `desc:` argument takes a single string description, while the
`long_desc:` argument takes an array of strings. Here is an example:

    flag :my_flag, "--my-flag",
         desc: "This is a short description for the arg",
         long_desc: ["Long descriptions may have multiple lines.",
                     "This is the second line."]

See the [above section on Descriptions](#Tool_descriptions) for more information on
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
[Toys::DSL::Flag class](https://dazuma.github.io/toys/gems/toys-core/latest/Toys/DSL/Flag).

#### Flag completions

Shell tab completion supports flag values, and flags can be configured to
present a set of completion candidates for themselves.

By default, a flag does not provide any completions for itself. To change that,
set the `completion` option. Currently there are three ways to set the
completion:

*   Provide a static set of possible values, as an array of strings.
*   Specify that values should be paths in the file system by setting the
    symbol `:file_system`.
*   Provide a `Proc` that returns possible values.

The following are two example flags, one that supports a static set of
completions and the other that supports file paths.

    flag :language, "--lang=VAL", complete_values: ["ruby", "elixir", "rust"]
    flag :path, "--path=VAL", complete_values: :file_system

Completions are somewhat related to acceptors, and it is a common pattern to
set both in concert. But they perform distinct functions. Acceptors affect
option parsing, whereas completions affect tab completion in the shell.

#### Flag groups

Flags may be organized into groups. This serves two functions:

*   Grouping related flags in the help and usage screens
*   Implementing required flags and other constraints

To create a simple flag group, use the `flag_group` directive, and provide a
block that defines the group's flags. You may also provide a group description
that appears in the help screen.

    flag_group desc: "Debug flags" do
      flag :debug, "-D", desc: "Enable debugger"
      flag :warnings, "-W[VAL]", desc: "Enable warnings"
    end

Flag groups may have a "type" that specifies constraints on the flags contained
in the group. Flags in a simple group like the above are ordinary optional
flags. However, you may specify that flags in the group are required using the
`all_required` directive:

    all_required desc: "Login flags (all required)" do
      flag :username, "--username=VAL", desc: "Set the username (required)"
      flag :password, "--password=VAL", desc: "Set the password (required)"
    end

If the tool is invoked without providing each of these required flags, it will
display an option parsing error.

The `all_required` directive is actually just shorthand for passing
`type: :required` to the `flag_group` directive. So the above is the same as:

    flag_group type: :required, desc: "Login flags (all required)" do
      flag :username, "--username=VAL", desc: "Set the username (required)"
      flag :password, "--password=VAL", desc: "Set the password (required)"
    end

The following are the supported types of flag groups:

*   The `:required` type, which you can create using the directive
    `all_required`. All flags from the group are required and must be provided
    on the command line to avoid an error.
*   The `:exactly_one` type, which you can create using the directive
    `exactly_one_required`. Exactly one, and no more than one, flag from the
    group must be provided on the command line to avoid an error.
*   The `:at_most_one` type, which you can create using the directive
    `at_most_one_required`. At most one flag from the group must be provided
    on the command line to avoid an error.
*   The `:at_least_one` type, which you can create using the directive
    `at_least_one_required`. At least one flag from the group must be provided
    on the command line to avoid an error.
*   The `:optional` type is the default created using the directive
    `flag_group` when no type is specified. Flags in the group are ordinary
    optional flags.

Flag group types are useful for a variety of tools. For example, suppose you
are writing a tool that deploys an app to one of several different kinds of
targets---say, a server, a VM, or a container. You could provide this
configuration for your tool with a flag group:

    tool "deploy" do
      exactly_one_required desc: "Deployment targets" do
        flag :server, "--server=IP_ADDR"
        flag :vm, "--vm=VM_ID"
        flag :container, "--container=CONTAINER_ID"
      end

      def run
        # Now exactly one of server, vm, or container will be set. The other
        # two options will be their default value, nil.
      end
    end

### Tool execution basics

When you run a tool from the command line, Toys will build the tool based on
its definition in a Toys file, and then it will attempt to execute it by
calling the `run` method. Normally, you should define this method in each of
your tools.

Note: If you do not define the `run` method for a tool, Toys provides a default
implementation that displays the tool's help screen. This is typically used for
namespaces, as we shall see [below](#Namespaces_and_subtools). Most tools,
however, should define `run`.

Let's revisit the "greet" example we covered earlier.

    tool "greet" do
      optional_arg :whom, default: "world"
      flag :shout, "-s", "--shout"

      def run
        greeting = "Hello, #{whom}!"
        greeting = greeting.upcase if shout
        puts greeting
      end
    end

Note that you can produce output or interact with the console using the normal
Ruby `$stdout`, `$stderr`, and `$stdin` streams.

Note also how the `run` method can access values that were assigned by flags or
positional arguments by just calling a method with that flag or argument name.
When you declare a flag or argument, if the option name is a symbol that is a
valid Ruby method name, Toys will provide a method that you can call to get the
value. In the above example, `whom` and `shout` are such methods.

If you create a flag or argument whose option name is not a symbol *or* is not
a valid method name, you can still get the value by calling the
[Toys::Context#get](https://dazuma.github.io/toys/gems/toys-core/latest/Toys/Context#get-instance_method)
method. For example:

    tool "greet" do
      # The name "whom-to-greet" is not a valid method name.
      optional_arg "whom-to-greet", default: "world"
      flag :shout, "-s", "--shout"

      def run
        # We can access the "whom-to-greet" option using the "get" method.
        greeting = "Hello, #{get('whom-to-greet')}!"
        greeting = greeting.upcase if shout
        puts greeting
      end
    end

If a tool's `run` method finishes normally, Toys will exit with a result code
of 0, indicating success. You may exit immediately and/or provide a nonzero
result by calling the
[Toys::Context#exit](https://dazuma.github.io/toys/gems/toys-core/latest/Toys/Context#exit-instance_method)
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
tool implementation. Indeed, a tool is actually a class under the hood, and
you can define methods as with any other class. Here's a contrived example:

    tool "greet-many" do
      # Support any number of arguments on the command line
      remaining_args :whom, default: ["world"]
      flag :shout, "-s", "--shout"

      # You can define helper methods like this.
      def greet(name)
        greeting = "Hello, #{name}!"
        greeting = greeting.upcase if shout
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

### Namespaces and subtools

Like many command line frameworks, Toys supports **subtools**. You may, for
example create a tool called "test" that runs your tests for a particular
project, but you might also want "test unit" and "test integration" tools to
run specific subsets of the test suite. One way to do this, of course, is for
the "test" tool to parse "unit" or "integration" as arguments. However, it's
often easier to define them as separate tools, subtools of "test".

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

    $ toys test unit
    run unit tests here...
    $ toys test integration
    run integration tests here...

Notice in this case, the parent "test" tool itself has no `run` method. This is
a common pattern: "test" is just a "container" for tools, a way of organizing
your tools. In Toys terminology, it is called a **namespace**. But it is still
a tool, and it can still be run:

    $ toys test

As discussed earlier, Toys provides a default implementation that displays the
help screen, which includes a list of the subtools and their descriptions.

As another example, the "root" tool is also normally a namespace. If you just
run Toys with no arguments:

    $ toys

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

## Understanding Toys files

Toys commands are defined in Toys files. We covered the basic syntax for these
files in the [above section on defining tools](#Defining_tools). In this
section, we will take a deeper look at what you can do with Toys files.

### Toys directories

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
name of the file `greet.rb` already provides a naming context: Toys already
knows that we are defining a "greet" tool.

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

#### Index files

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
[section on sharing code](#Sharing_code).

### The Toys search path

So far we have seen how to define tools by writing a `.toys.rb` file in the
current directory, or by writing files inside a `.toys` directory in the
current directory. These tools are "scoped" to the current directory. If you
move to a different directory, they may not be available.

When Toys runs, it looks for tools in a **search path**. Specifically:

1.  It looks for a `.toys.rb` file and/or a `.toys` directory in the *current
    working directory*.
2.  It does the same in the *parent directory* of the current directory, and
    then its parent, and so on until it hits either the root of the file system
    or one of the global directories described in (3).
3.  It looks in a list of *global directories*, specified in the environment
    variable `TOYS_PATH`. This variable can contain a colon-delimited list of
    directory paths. If the variable is not set, the current user's *home
    directory*, and the system configuration directory (`/etc` on unix systems)
    are used by default. Toys does *not* search parents of global directories.

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

Note that in the search path above, steps (1) and (2) are *context-dependent*.
That is, they may be different depending on what directory you are in. However,
step (3) is *not* context-dependent, and is searched regardless of where you
are located. Tools defined here are *global*, available everywhere.

#### Stopping search

Though it is uncommon practice, it is possible to stop the search process and
prevent Toys from loading tools further down in the search path (e.g. prevent
tools from being defined from parent directories or global directories). To do
so, use the directive
[Toys::DSL::Tool#truncate_load_path!](https://dazuma.github.io/toys/gems/toys-core/latest/Toys/DSL/Tool#truncate_load_path!-instance_method). This directive removes all
directories further down the search path. It can be used, for example, to
disable global tools when you run Toys from the current directory. It can also
be useful if you are using [Bundler integration](#Using_bundler_with_a_tool) to
prevent bundle conflicts with parent directories, by disabling tools from
parent directories.

The `truncate_load_path!` directive works only if no tools from further down
the search path have been loaded yet. It will raise
[Toys::ToolDefinitionError](https://dazuma.github.io/toys/gems/toys-core/latest/Toys/ToolDefinitionError)
if it fails to truncate the load path. In most cases, Toys is very smart about
loading tools only when needed, but there are exceptions. To minimize the
chance of problems, if you need to use `truncate_load_path!`, locate it as
early as possible in your Toys files, typically at the top of the
[index file](#Index_files).

## The execution environment

This section describes the context and resources available to your tool when it
is running; that is, what you can call from your tool's `run` method.

Each tool is defined as a class that subclasses
[Toys::Context](https://dazuma.github.io/toys/gems/toys-core/latest/Toys/Context).
The base class defines helper methods, and provides access to a variety of data
and objects relevant to your tool. We have already seen earlier how to use the
[Toys::Context#get](https://dazuma.github.io/toys/gems/toys-core/latest/Toys/Context#get-instance_method)
method to retrieve option values, and how to use the
[Toys::Context#exit](https://dazuma.github.io/toys/gems/toys-core/latest/Toys/Context#exit-instance_method)
method to exit immediately and return an exit code. Now we will cover other
resources available to your tool.

### Built-in context

In addition to the options set by your tool's flags and command line arguments,
a variety of other data and objects are also accessible using the
[Toys::Context#get method](https://dazuma.github.io/toys/gems/toys-core/latest/Toys/Context#get-instance_method)
For example, you can get the full name of the tool being executed like this:

    def run
      puts "Current tool is #{get(TOOL_NAME)}"
    end

The `TOOL_NAME` constant above is a well-known key that corresponds to the full
name (as an array of strings) of the running tool. A variety of well-known keys
are defined in the
[Toys::Context::Key module](https://dazuma.github.io/toys/gems/toys-core/latest/Toys/Context/Key).
They include information about the current execution, such as the tool name and
the original command line arguments passed to it (before they were parsed).
They also include some internal Toys objects, which can be used to do things
like write to the logger or look up and call other tools.

Most of the important context also can be accessed from convenience methods.
For example, the `TOOL_NAME` is also available from the
[Toys::Context#tool_name method](https://dazuma.github.io/toys/gems/toys-core/latest/Toys/Context#tool_name-instance_method):

    def run
      puts "Current tool is #{tool_name}"
    end

Let's take a look at a few things your tool can do with the objects you can
access from built-in context.

### Logging and verbosity

Toys provides a Logger (a simple instance of the Ruby standard library logger
that writes to standard error) for your tool to use to report status
information. You can access this logger via the `LOGGER` context key, or the
[Toys::Context#logger method](https://dazuma.github.io/toys/gems/toys-core/latest/Toys/Context#logger-instance_method).
For example:

    def run
      logger.warn "Danger Will Robinson!"
    end

The current logger level is controlled by the verbosity. Verbosity is an
integer context value that you can retrieve using the `VERBOSITY` context key
or the
[Toys::Context#verbosity method](https://dazuma.github.io/toys/gems/toys-core/latest/Toys/Context#verbosity-instance_method).
The verbosity is set to 0 by default. This corresponds to a logger level of
`WARN`. That is, warnings, errors, and fatals are displayed, while infos and
debugs are not. However, [as we saw earlier](#Standard_flags), most tools
automatically respond to the `--verbose` and `--quiet` flags, (or `-v` and
`-q`), which increment and decrement the verbosity value, respectively. If you
run a tool with `-v`, the verbosity is incremented to 1, and the logger level
is set to `INFO`. If you set `-q`, the verbosity is decremented to -1, and the
logger level is set to `ERROR`. So by using the provided logger, a tool can
easily provide command line based control of the output verbosity.

### Running tools from tools

A common operation a tool might want to do is "call" another tool. This can be
done via the CLI object, which you can retrieve using the `CLI` key or the
[Toys::Context#cli method](https://dazuma.github.io/toys/gems/toys-core/latest/Toys/Context#cli-instance_method).
These return the current instance of
[Toys::CLI](https://dazuma.github.io/toys/gems/toys-core/latest/Toys/CLI) which
is the "main" interface to Toys. In particular, it provides the
[Toys::CLI#run method](https://dazuma.github.io/toys/gems/toys-core/latest/Toys/CLI#run-instance_method)
which can be used to call another tool:

    def run
      status = cli.run("greet", "rubyists", "-v")
      exit(status) unless status.zero?
    end

Pass the tool name and arguments as arguments to the run method. It will
execute, and return a process status code (i.e. 0 for success, and nonzero for
error). Make sure you handle the exit status. For example, in most cases, you
should probably exit if the tool you are calling returns a nonzero code.

You may also use the `exec` mixin [described below](#Executing_subprocesses) to
run a tool in a separate process. This is particularly useful if you need to
capture or manipulate that tool's input or output stream.

### Helper methods and mixins

The methods of [Toys::Context](https://dazuma.github.io/toys/gems/toys-core/latest/Toys/Context)
are not the only methods available for your tool to call. We
[saw earlier](#Tool_execution_basics) that a tool can define additional methods
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
[Toys::StandardMixins](https://dazuma.github.io/toys/gems/toys-core/latest/Toys/StandardMixins).
We will look at a few examples of the use of these mixins below. Built-in
mixins have names that are symbols.

You can also define your own mixins, as we will see in the
[upcoming section on defining mixins](#Defining_mixins).

### Executing subprocesses

Another common operation you might do in a tool is to execute other binaries.
For example, you might write a tool that shells out to `scp` to copy files to
a remote server.

Ruby itself provides a few convenient methods for simple execution, such as the
[Kernel#system](http://ruby-doc.org/core/Kernel.html#method-i-system) method.
However, these typically provide limited ability to control or interact with
subprocess streams, and you also need to remember to handle the exit status
yourself. If you do want to exert more control over subprocesses, you can use
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
[Toys::StandardMixins::Exec mixin module](https://dazuma.github.io/toys/gems/toys-core/latest/Toys/StandardMixins/Exec)
and the underyling library
[Toys::Utils::Exec](https://dazuma.github.io/toys/gems/toys-core/latest/Toys/Utils/Exec).

### Formatting output

Interacting with the user is a very common function of a command line tool, and
many modern tools include intricately designed and styled output, and terminal
effects such as progress bars and spinners. Toys provides several mixins that
can help create nicer interfaces.

First, there is `:terminal`, which provides some basic terminal features such
as styled output and simple spinners. For information, see the
[Toys::StandardMixins::Terminal mixin module](https://dazuma.github.io/toys/gems/toys-core/latest/Toys/StandardMixins/Terminal)
and the underyling library
[Toys::Terminal](https://dazuma.github.io/toys/gems/toys-core/latest/Toys/Terminal).

If you prefer the venerable Highline library interface, Toys provides a mixin
called `:highline` that automatically installs the highline gem (version 2.x)
if it is not available, and makes a highline object available to the tool. For
more information, see the
[Toys::StandardMixins::Highline mixin module](https://dazuma.github.io/toys/gems/toys-core/latest/Toys/StandardMixins/Highline).

You may also use other third-party gems such as
[tty](https://github.com/piotrmurach/tty). The section below on
[useful gems](#Useful_gems) provides some examples.

## Sharing code

As you accumulate additional and more complex tools, you may find that some of
your tools need to share some common configuration, data, or logic. You might,
for example, have a set of admin scripts that need to do some common
authentication. This section describes several techniques for sharing code
between tools, and describes the scope of Ruby structures, such as methods,
classes, and constants, that you might define in your tools.

### Defining mixins

We [saw earlier](#Helper_methods_and_mixins) that you can mix a module (with
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
[using constants](#Using_constants) to learn how Toys handles constants.)

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

A common technique, for example, would be to define a mixin in the
[index file](#Index_files) in a Toys directory. You can then include it from
any subtools defined in other files in that same directory.

#### Mixin initializers

Sometimes a mixin will want to initialize some state before the tool executes.
For example, the `:highline` mixin creates an instance of Highline during tool
initialization. To do so, provide an `on_initialize` block in the mixin block.
The initializer block is called within the context of the tool after arguments
are parsed, so it has access to the tool's built-in context and options.

If you provide extra arguments when you `include` a mixin, those are passed to
the initializer block.

For example, suppose the `"common_test_code"` mixin needs to behave differently
depending on the type of tests (unit vs integration). Let's have the subtools
pass a value to the mixin's initializer:

    tool "test" do
      mixin "common_test_code" do
        # Initialize the mixin, and receive the argument passed to the
        # include directive
        on_initialize do |type|
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

#### Mixin inclusion hooks

A mixin can also optionally provide directives to run when the mixin is
included, by defining an `on_include` block. (This is functionally similar to
defining an `included` method on a Ruby module.) The `on_include` block is
called within the context of the tool DSL, so it can invoke any DSL directives.

If you provide extra arguments when you `include` a mixin, those are passed to
the inclusion block.

### Using constants

You can define and use Ruby constants, i.e. names beginning with a capital
letter, in a Toys file. However, they are subject to Ruby's rules regarding
constant scope and lookup, which can be confusing, especially in a DSL. Toys
tries to simplify those rules and make constant behavior somewhat tractable,
but if you do use constants (which includes modules and classes defined in a
Toys file), it is important to understand how they work.

Constants in Toys are visible only within the Toys file in which they are
defined. They normally behave as though they are defined at the "top level" of
the file. Even if you define a constant lexically "inside" a tool or a mixin,
the constant does *not* end up connected to that tool or mixin; it is defined
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
them with `self::`. However, this is uncommon Ruby practice and is mildly
discouraged.)

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
directive creates mixins that are visible from *all* files at the same point in
the search path.

Not also, when you define a mixin in this way, you should include `Toys::Mixin`
in the module, as illustrated above. This makes `on_initialize` available in
the module.

### Templates

Another way to share code is to expand a **template**.

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
[Toys as a Rake replacement](#Toys_as_a_Rake_replacement).

You may also write your own templates. Here's how...

#### Defining templates

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

      on_expand do |template|
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

Next, a template has an `on_expand` block. This block contains the Toys file
directives that should be generated by the template. The template object is
passed to the block, so it can access the template configuration when
generating directives. The "greet" template in the above example generates a
tool whose name is set by the template's `name` property.

Notice that in the above example, we used `to_run do`, providing a *block* for
the tool's execution, rather than `def run`, providing a method. Both forms are
valid and will work in a template (as well as in a normal Toys file), but the
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

#### Template classes

Finally, templates are classes, and you can create a template directly as a
class by including the
[Toys::Template](https://dazuma.github.io/toys/gems/toys-core/latest/Toys/Template)
module in your class definition.

    class GreetTemplate
      include Toys::Template

      def initialize(name: "greet", whom: "world")
        @name = name
        @whom = whom
      end
      attr_accessor :name
      attr_accessor :whom

      on_expand do |template|
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
but you can omit it if you use the `template` directive to define the template
in a block.

Defining templates as classes is also a useful way for third-party gems to
provide Toys integration. For example, suppose you are writing a code analysis
gem, and you want to make it easy for your users to create a Toys tool that
invokes your analysis. Just write a template class in your gem, maybe named
`MyAnalysis::ToysTemplate`. Now, just instruct your users to include the
following in their Toys file:

    require "my_analysis"
    expand MyAnalysis::ToysTemplate

### Loading from a lib directory

For more complicated tools, you might want to write normal Ruby modules and
classes as helpers. Toys provides a way to write Ruby code outside of its DSL
and `require` the code from your tool, using `.lib` directories.

To use `.lib` directories, you must define your tools inside a
[Toys directory](#Toys_directories). When a tool is executed, it looks for
directories called `.lib` in the Toys directory, and adds them to the Ruby load
path. Your tool can thus call `require` to load helpers from any Ruby files in
a `.lib` directory.

For example, take the following directory structure:

    (current directory)
    |
    +- .toys/
       |
       +- .lib/   <-- available when a tool is executed
       |  |
       |  +- greeting_helper.rb
       |
       +- greet.rb

The `greeting_helper.rb` file can contain any Ruby code.

    # .toys/.lib/greeting_helper.rb

    module GreetingHelper
      def self.make_greeting(whom)
        "Hello, #{whom}!"
      end
    end

Now you can `require "greeting_helper"` in your `greet` tool.

    # .toys/greet.rb

    tool "greet" do
      optional_arg :whom, default: "world", desc: "Whom to greet."
      def run
        require "greeting_helper"
        puts GreetingHelper.make_greeting(whom)
      end
    end

Note that `.lib` directories are available only when your tool is being *run*,
not when it is being defined. So any `require` statements should be located
*inside* your `run` method.

    tool "greet" do
      # Do not try to require the file here. Toys will not find it because
      # the tool is not yet being run.
      # require "greeting_helper"  # ERRORS!

      optional_arg :whom, default: "world", desc: "Whom to greet."
      def run
        # Require a helper file here, so it is loaded during tool execution.
        require "greeting_helper"
        # Now you can use classes defined in the helper
        puts GreetingHelper.make_greeting(whom)
      end
    end

If your Toys directory has subdirectories, lib directories will be prioritized
by how close they are to the tool being executed. For example:

    (current directory)
    |
    +- .toys/
       |
       +- .lib/   <-- available when any tool defined in this directory
       |  |           is executed
       |  |
       |  +- helper.rb   <-- visible to "greet" but not "test unit"
       |  |
       |  +- helper2.rb   <-- visible to both "greet" and "test unit"
       |
       +- greet.rb
       |
       +- test/
          |
          +- .lib/   <-- available only when tools under "test" are executed
          |  |
          |  +- helper.rb   <-- overrides the other helper.rb when
          |                     "test unit" is executed
          |
          +- unit.rb

### Preloading Ruby files

You may also provide Ruby files that are "preloaded" before tools are defined.
This is useful if those Ruby files are required by the tool definitions
themselves. Like files in the `.lib` directory, preloaded files can define Ruby
classes, modules, and other code. But preloaded files *automatically* loaded
(i.e. you do not `require` them explicitly) *before* your tools are defined.

To use preloaded files, you must define your tools inside a
[Toys directory](#Toys_directories). Before any tools inside a directory are
loaded, any file named `.preload.rb` in the directory is automatically
required. Additionally, any Ruby files inside a subdirectory called `.preload`
are also automatically required.

For example, take the following directory structure:

    (current directory)
    |
    +- .toys/
       |
       +- .preload.rb   <-- required first
       |
       +- greet.rb   <-- defines "greet" (and subtools)
       |
       +- test/
          |
          +- .preload/
          |  |
          |  +- my_classes.rb  <-- required before unit.rb
          |  |
          |  +- my_modules.rb  <-- also required before unit.rb
          |
          +- unit.rb   <-- defines "test unit" (and its subtools)

Toys will execute

    require ".toys/.preload.rb"

first before loading any of the tools in the `.toys` directory (or any of its
subdirectories). Thus, you can define classes used by both the `greet` and the
`test unit` tool in this file.

Furthermore, Toys will also execute

    require ".toys/test/.preload/my_classes.rb"
    require ".toys/test/.preload/my_modules.rb"

first before loading any of the tools in the `test` subdirectory. Thus, any
additional classes needed by `test unit` can be defined in these files.

Either a single `.preload.rb` file or a `.preload` directory, or both, may be
used. If both are present in the same directory, the `.preload.rb` file is
loaded first before the `.preload` directory contents.

## Using third-party gems

The toys executable itself uses only two gems: **toys** and **toys-core**. It
has no other gem dependencies. However, the Ruby community has developed many
resources for building command line tools, including a variety of gems that
provide alternate command line parsing, control of the ANSI terminal, formatted
output such as trees and tables, and effects such as hidden input, progress
bars, various ways to spawn and control subprocesses, and so forth. You may
find some of these gems useful when writing your tools. Additionally, if you
are using Toys for your project's build scripts, it might be necessary to
install your bundle when running some tools.

This section describes how to manage and use external gems with Toys. Note that
running Toys with `bundle exec` is generally *not* recommended. We'll discuss
the reasons for this, and what you can do instead.

### Why not "bundle exec toys"

[Bundler](https://bundler.io) is often used when a command-line program depends
on external gems. You specify the gem dependencies in a `Gemfile`, use bundler
to resolve and install those dependencies, and then run the program prefixed by
`bundle exec` to ensure those dependencies are in the Ruby load path. When
running a Rake task, for example, it is almost automatic for many Ruby
developers to run `bundle exec rake my-task`.

So why not simply run `bundle exec toys my-tool`?

In simple cases, this will work just fine. However, Toys is a much more
flexible tool than Rake, and it covers two cases that are not well served by
`bundle exec`.

First, Toys lets you define *global tools* that are defined in your home
directory or system config directory. (See the previous section on
[the Toys search path](#The_Toys_search_path).) These tools are global, and can
be called from anywhere. But if they have gem dependencies, it might not be
feasible for their Gemfiles to be present in every directory from which you
might want to run them.

Second, it's possible for a variety of tools to be available together,
including both locally and globally defined, with potentially different sets of
dependencies. With `bundle exec`, you must choose beforehand which bundle to
use.

Although traditional `bundle exec` doesn't always work, Toys provides ways for
individual tools to manage their own gem dependencies.

### Using bundler with a tool

The recommended way for a Toys tool to depend on third-party gems is for the
tool to set up Bundler when it runs. The tool can load a bundle from an
appropriate `Gemfile` at runtime, by including the `:bundler` mixin.

Here's an example. Suppose you are writing a tool in a Rails app. It might, for
example, load the Rails environment and populate some data into the database.
Hence, it needs to run with your app's bundle, represented by your app's
`Gemfile`.

Simply `include :bundler` in your tool definition:

    tool "populate-data" do
      include :bundler

      def run
        # The bundle will be set up before the tool is run,
        # so you can now run code that depends on rails:
        require "./config/environment.rb"
        # ... etc.
      end
    end

When the `:bundler` mixin is included in a tool, it installs a
[mixin initializer](#Mixin_initializers) that calls `Bundler.setup` when the
tool is *executed*. This assumes the bundle is already installed, and brings
the appropriate gems into the Ruby load path. That is, it's basically the same
as `bundle exec`, but it applies only to the running tool.

#### Applying bundler to all subtools

In many cases, you might find that bundler is needed for many or most of the
tools you write for a particular project. In this case, you might find it
convenient to use
[Toys::DSL::Tool#subtool_apply](https://dazuma.github.io/toys/gems/toys-core/latest/Toys/DSL/Tool#subtool_apply-instance_method)
to include the bundle in all your tools. For example:

    # Include bundler in every tool under this one
    subtool_apply do
      include :bundler
    end

    tool "one-tool" do
      # This tool will run with the bundle
      # ...
    end

    tool "another-tool" do
      # So will this tool
      # ...
    end

See the section on
[applying directives to multiple tools](#Applying_directives_to_multiple_tools)
for more information on `subtool_apply`.

#### Bundler options

By default, the `:bundler` mixin will look for a `Gemfile` within the `.toys`
directory (if your tool is defined in one), and if one is not found there,
within the [context directory](#The_context_directory) (the directory
containing your `.toys` directory or `.toys.rb` file), and if one still is not
found, in the current working directory. You can change this behavior by
passing an option to the `:bundler` mixin. For example, you can search only the
current working directory by passing `search_dirs: :current` as such:

    tool "populate-data" do
      include :bundler, search_dirs: :current
      # etc...
    end

The `:search_dirs` option takes a either directory path (as a string) or a
symbol indicating a "semantic" directory. You can also pass an array of
directories that will be searched in order. For each directory, Toys will look
for a file called `.gems.rb`, `gems.rb`, or `Gemfile` (in that order) and use
the first one that it finds.

The supported "semantic directory" symbols are `:current` indicating the
current working directory, `:context` indicating the context directory, and
`:toys` indicating the Toys directory in which the tool is defined.
Furthermore, the semantic directory `:toys` is treated specially in that it
looks up the `.toys` directory hierarchy. So if your tool is defined in
`.toys/foo/bar.rb`, it will look for a Gemfile first in `.toys/foo/` and then
in `.toys/`. Additionally, when looking for a Gemfile in `:toys`, it searches
only for `.gems.rb` and `Gemfile`. A file called `gems.rb` is not treated as a
Gemfile under the `:toys` directory, because it could be a tool.

The default gemfile search path, if you do not provide the `search_dirs:`
option, is equivalent to `[:toys, :context, :current]`.

If the bundle is not installed, or is out of date, Toys will ask you whether
you want it to install the bundle first before running the tool. A tool can
also choose to install the bundle without prompting, or simply to raise an
error, by passing another option to the `:bundler` mixin. For example, to
simply install the bundle without asking for confirmation:

    tool "populate-data" do
      include :bundler, on_missing: :install
      # etc...
    end

See the documentation for
[Toys::StandardMixins::Bundler](https://dazuma.github.io/toys/gems/toys-core/latest/Toys/StandardMixins/Bundler)
for more information about bundler options.

#### Solving bundle conflicts

It is important to understand that the `:bundler` mixin installs the bundle
when the tool *executes*, rather than when the tool is defined. Gems in the
bundle will not be available during tool definition, so for example you
*cannot* reference bundled gems when you are setting up the tool's flags,
description, or other directives. This is so that Toys can define tools with
competing bundles. Your Rails app's tools can use that app's bundle, while your
global tools can use a different bundle. They will not conflict because Toys
will not actually load a bundle until one or the other tool is executed. (This
is of course different from using `bundle exec`, which chooses and loads a
bundle before even starting Toys.)

If a *different* bundle (i.e. a different `Gemfile`) is already in effect when
a tool is run, then the `:bundler` mixin will raise an error. Ruby will not let
you set up two different bundles at the same time. This might happen, for
example, if you use `bundle exec` to run Toys, but the tool you are running
asks for a different bundle---one more reason not to use `bundle exec` with
Toys.

It might also happen if one tool that uses one bundle, *calls* a tool that uses
a different bundle. If you need to do this, use the
[Toys::StandardMixins::Exec#exec_separate_tool](https://dazuma.github.io/toys/gems/toys-core/latest/Toys/StandardMixins/Exec#exec_separate_tool-instance_method)
method from the `:exec` mixin, to call the tool. This method spawns a separate
process with a clean Bundler setup for running the tool.

#### When a bundle is needed to define a tool

Usually, the `:bundler` mixin sets up your bundle when the tool is *executed*.
However, occasionally, you need the gems in the bundle to *define* a tool. This
might happen, for instance, if your bundle includes gesm that define mixins or
templates used by your tool.

If you need the bundle set up immediately because its gems are needed by the
tool definition, pass the `static: true` option when including the `:bundler`
mixin. For example, if you are using the
[flame_server_toys](https://github.com/AlexWayfer/flame_server_toys) gem, which
provides a template that generates tools for the
[Flame](https://github.com/AlexWayfer/flame) web framework, you could include
the `flame_server_toys` gem in your Gemfile, and make it available for defining
tools:

    # Set up the bundle immediately.
    include :bundler, static: true

    # Now you can use the gems in the bundle when defining tools.
    require "flame_server_toys"
    expand FlameServerToys::Template

There is a big caveat to using `static: true`, which is that you are setting up
a bundle immediately, and as a result any subsequent attempt to set up or use a
different bundle will fail. (See the section on
[bundle conflicts](#Solving_bundle_conflicts) for a discussion of other reasons
this can happen.) As a result, it's best not to use `static: true` unless you
*really* need it to define tools. If you do run into this problem, here are two
things you could try:

 1. "Scope" the bundle to the tool or the namespace where you need it. Toys
    makes an effort not to define a tool unless you actually need to execute it
    or one of its subtools, so if you can locate `include :bundler` inside just
    the tool or namespace that needs it, you might be able to avoid conflicts.

 2. Failing that, if you need a particular gem in order to define a tool, you
    could consider activating the gem directly rather than as part of a bundle.
    See the following section on
    [Activating gems directly](#Activating_gems_directly) for details on this
    technique.

### Activating gems directly

Although we recommend the `:bundler` mixin for most cases, it is also possible
for a tool to install individual gems, using the `:gems` mixin. This mixin
provides a way for a tool to install individual gems without using Bundler.

Here's an example tool that just runs `rake`. Because it requires rake to be
installed in order to run the tool, we call the
[Toys::StandardMixins::Gems#gem](https://dazuma.github.io/toys/gems/toys-core/latest/Toys/StandardMixins/Gems#gem-instance_method)
method (which is provided by the `:gems` mixin) at the beginning of the `run`
method:

    tool "rake" do
      include :gems
      remaining_args :rake_args
      def run
        gem "rake", "~> 12.0"
        Kernel.exec(["rake"] + rake_args)
      end
    end

The `gem` method takes the name of the gem, and an optional set of version
requirements. If a gem matching the given version requirements is installed, it
is activated. If not, the gem is installed (which the user can confirm or
abort). Or, if Toys is being run in a bundle, a message is printed informing
the user that they need to add the gem to their Gemfile.

If a gem satisfying the given version constraints is already activated, it
remains active. If a gem with a conflicting version is already activated, an
exception is raised.

The `:gems` mixin also provides a `gem` *directive* that ensures a gem is
installed while the tool is being defined. In general, we recommend avoiding
doing this, because it could make your tool incompatible with another tool that
might need a competing gem during its definition. Toys would not be able to
define both tools together. However, occasionally it might be useful.

Here's an example tool with flags for each of the HighLine styles. Because
highline is needed to decide what flags to define, we use the `gem` directive
to ensure highline is installed while the tool is being defined.

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
      end
    end

Note these methods are a bit different from the
[gem method](http://ruby-doc.org/stdlib/libdoc/rubygems/rdoc/Kernel.html)
provided by Rubygems. The Toys version attempts to install a missing gem for
you, whereas Rubygems will just throw an exception.

### Activating gems outside the DSL

The above techniques for installing a bundle or activating a gem directly, are
all part of the tool definition DSL. However, the functionality is also
available outside the DSL---for example, from a class-based mixin.

To set up a bundle, call
[Toys::Utils::Gems#bundle](https://dazuma.github.io/toys/gems/toys-core/latest/Toys/Utils/Gems#bundle-instance_method).
(Note that you must `require "toys/utils/gems"` explicitly before invoking the
[Toys::Utils::Gems](https://dazuma.github.io/toys/gems/toys-core/latest/Toys/Utils/Gems)
class because, like all classes under `Toys::Utils`, Toys does not load it
automatically.) For example:

    require "toys/utils/gems"
    gem_utils = Toys::Utils::Gems.new
    gem_utils.bundle(search_dirs: Dir.getwd)

To activate single gems explicitly, call
[Toys::Utils::Gems#activate](https://dazuma.github.io/toys/gems/toys-core/latest/Toys/Utils/Gems#activate-instance_method).
For example:

    require "toys/utils/gems"
    gem_utils = Toys::Utils::Gems.new
    gem_utils.activate("highline", "~> 2.0")

### Useful gems

Now that you know how to ensure a gem is installed, either individually or as
part of a bundle, let's look at some third-party gems that you might find
useful when writing tools.

We already saw how to use the **highline** gem. Highline generally provides two
features: terminal styling, and prompts. For these capabilities and many more,
you might also consider [TTY](https://github.com/piotrmurach/tty). It comprises
a suite of gems that you can use separately or in tandem. Here are a few
examples.

To produce styled output, consider
[Pastel](https://github.com/piotrmurach/pastel).

    tool "fancy-output" do
      def run
        require "pastel"
        pastel = Pastel.new
        puts pastel.red("Rubies!")
      end
    end

To create rich user prompts, consider
[tty-prompt](https://github.com/piotrmurach/tty-prompt).

    tool "favorite-language" do
      def run
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

## Toys as a Rake replacement

Toys was designed to organize scripts that may be "scoped" to a project or
directory. Rake is also commonly used for this purpose: you can write a
"Rakefile" that defines rake tasks scoped to a directory. In many cases, Toys
can be used as a replacement for Rake. Indeed, the Toys repository itself
contains a `.toys.rb` file instead of a Rakefile, for running tests, builds,
and so forth.

This section will explore the differences between Toys and Rake, and describe
how to use Toys for some of the things traditionally done with Rake.

### Comparing Toys and Rake

Although Toys and Rake serve many of the same use cases, they have very
different design goals, and it is useful to understand them.

Rake's design is based on the classic "make" tool often provided in unix
development environments. This design focuses on *targets* and *dependencies*,
and is meant for a world where you invoke an external compiler tool whenever
changes are made to an individual source file or any of its dependencies. This
"declarative" approach expresses very well the build process for programs
written in C and similar compiled languages.

Ruby, however, does not have an external compiler, and certainly not one that
requires separate invocation for each source file as does the C compiler. So
although Rake does support file dependencies, they are much less commonly used
than in their Makefile cousins. Instead, in practice, most Rake tasks are not
connected to a dependency at all; they are simply standalone scripts, what
would be called "phony" targets in a Makefile. Such tasks are more imperative
than declarative.

The Toys approach to build tools simply embraces the fact that our build
processes already tend to be imperative. So unlike Rake, Toys does not provide
syntax for describing targets and dependencies, since we generally don't have
them in Ruby programs. Instead, it is optimized for writing imperative tools.

For example, Rake provides a primitive mechanism for passing arguments to a
task, but it is clumsy and quite different from most unix programs. However, to
do otherwise would clash with Rake's design goal of treating tasks as targets
and dependencies. Toys does not have those design goals, so it is able to
embrace the familiar unix conventions for command line arguments.

Toys actually borrows some of its design from the "mix" build tool used for
Elixir and Erlang programs. Unlike C, the Erlang and Elixir compilers do their
own dependency management, so mix does not require those capabilities. Instead,
it focuses on making it easy to define imperative tasks.

All told, this boils down to the principle of using the best tool for the job.
There will be times when you need to express file-based dependencies in some of
your build tasks. Rake will continue to be your friend in those cases. However,
for imperative tasks such as "run my tests", "build my YARD documentation", or
"release my gem", you may find Toys easier to use.

### Using Toys to invoke Rake tasks

If you've already written a Rakefile for your project, Toys provides a
convenient way to invoke your existing Rake tasks using Toys. The built-in
`:rake` template reads a Rakefile and automatically generates corresponding
tools.

In the same directory as your Rakefile, create a `.toys.rb` file with the
following contents:

    # In .toys.rb
    expand :rake

Now within that directory, if you had a Rake task called `test`, you can invoke
it with:

    $ toys test

Similarly, a Rake task named `test:integration` can be invoked with either of
the following:

    $ toys test integration
    $ toys test:integration

Rake tasks with arguments are mapped to tool arguments, making it easier to
invoke those tasks using Toys. For example, consider a Rake task with two
arguments, defined as follows:

    # In Rakefile
    task :my_task, [:first, :second] do |task, args|
      do_something_with args[:first]
      do_something_else_with args[:second]
    end

would have to be invoked as follows using rake:

    $ rake my_task[value1,value2]

You may even need to escape the brackets if you are using a shell that treats
them specially. Toys will let you pass them as normal command line arguments:

    $ toys my_task value1 value2

The `:rake` template provides several options. If your Rakefile is named
something other than `Rakefile` or isn't in the current directory, you can
pass an explicit path to it when expanding the template:

    # In .toys.rb
    expand :rake, rakefile_path: "path/to/my_rakefile"

You may also choose to pass arguments as named flags rather than command line
arguments. Set `:use_flags` when expanding the template:

    # In .toys.rb
    expand :rake, use_flags: true

Now with this option, to pass arguments to the tool, use the argument names as
flags:

    $ toys my_task --first=value1 --second=value2

### From Rakefiles to Toys files

Invoking Rake tasks using Toys is an easy first step, but eventually you will
likely want to migrate some of your project's build tasks from Rake to Toys.
The remainder of this section describes the common patterns and features Toys
provides for writing build tasks that are traditionally done with Rake.

Many common Rake tasks can be generated using code provided by either Rake or
the third party library. Different libraries provide different mechanisms for
task generation. For example, a test task might be defined like this:

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

### Running tests

Toys provides a built-in template called `:minitest` for running unit tests
with [minitest](https://github.com/seattlerb/minitest). The following example
directive uses the minitest template to create a tool called `test`:

    expand :minitest, files: ["test/test*.rb"], libs: ["lib", "ext"]

See the {Toys::Templates::Minitest} documentation for details on the available
options.

Toys also provides a built-in template called `:rspec` for running BDD examples
using [RSpec](http://rspec.info). The following example directive uses this
template to create a tool called `spec`:

    expand :rspec, pattern: "spec/**/*_spec.rb", libs: ["lib, "ext"]

See the {Toys::Templates::Rspec} documentation for details on the available
options.

If you want to enforce code style using the
[rubocop gem](https://rubygems.org/gems/rubocop), you can use the built-in
`:rubocop` template. The following directive uses this template to create a
tool called `rubocop`:

    expand :rubocop

See the {Toys::Templates::Rubocop} documentation for details on the available
options.

### Building and releasing gems

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

### Building documentation

Toys provides an `:rdoc` template for creating tools that generate RDoc
documentation, and a `:yardoc` template for creating tools that generate YARD.
Both templates provide a variety of options for controlling documentation
generation. See {Toys::Templates::Rdoc} and {Toys::Templates::Yardoc} for
detailed information.

Here's an example for YARD, creating a tool called `yardoc`:

    expand :yardoc, protected: true, markup: "markdown"

### Gem example

Let's look at a complete example that combines the techniques above to provide
all the basic tools for a Ruby gem. It includes:

* A testing tool that can be invoked using `toys test`
* Code style checking using Rubocop, invoked using `toys rubocop`
* Documentation building using Yardoc, invoked using `toys yardoc`
* Gem building, invoked using `toys build`
* Gem build and release to Rubygems.org, invoked using `toys release`
* A full CI tool, invoked using `toys ci`, that can be run from your favorite
  CI system. It runs the tests and style checks, and checks (but does not
  actually build) the documentation for warnings and completeness.

Below is the full annotated `.toys.rb` file. For many gems, you could drop this
into the gem source repo with minimal or no modifications. Indeed, it is very
similar to the Toys files provided for the **toys** and **toys-core** gems
themselves.

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

    # An "install" tool that builds the gem and installs it locally.
    expand :gem_build, name: "install", install_gem: true

    # A full gem "release" tool that builds the gem, and pushes it to rubygems.
    # This assumes your local rubygems configuration is set up with the proper
    # credentials.
    expand :gem_build, name: "release", push_gem: true

    # Now we create a full CI tool. It runs the test, rubocop, and yardoc tools
    # and checks for errors. This tool could be invoked from a CI system.
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

## Advanced tool definition techniques

This section covers some additional features that are often useful for writing
tools. I've labeled them "advanced", but all that really means is that this
user's guide didn't happen to have covered them until this section. Each of
these features is very useful for certain types of tools, and it is good at
least to know that you *can* do these things, even if you don't use them
regularly.

### Delegating tools

A tool may **delegate** to another tool, which means it uses the other tool's
flags, arguments, and execution. Effectively, it becomes an "alias"---that is,
an alternate name---for the target tool.

For example, suppose you have a tool called `test` that can be invoked with
`toys test`. You could define a tool `t` that delegates to `test`. Then,
running `toys t` will have the same effect as `toys test`.

To delegate a tool, pass the `:delegate_to` keyword argument to the `tool`
directive. For example:

    tool "test" do
      # Define test tool here...
    end

    tool "t", delegate_to: "test"

Tools can delegate to tools or namespaces. For example, you can delegate `sys`
to the built-in namespace `system`:

    tool "sys", delegate_to: "system"

That will let you run `toys sys version` (which will be the equivalent of
`toys system version`).

To delegate to a subtool, pass an array, or a string delimited by `":"` or
`"."` characters, as the target:

    tool "gem" do
      tool "test" do
        # Define the tool here
      end
    end

    tool "test", delegate_to: ["gem", "test"]

In most cases, if a tool delegates to another tool, you should not do anything
else with it. For example, it should not have its own implementation or contain
any subtools. However, there are a few exceptions. You might, for example, want
a namespace to delegate to one of its subtools:

    tool "test", delegate_to: ["test", "unit"] do
      tool "unit" do
        # Run unit tests
      end
      tool "integration" do
        # Run integration tests
      end
    end

Now `toys test` delegates to, and thus has the same effect as `toys test unit`.

### Applying directives to multiple tools

Sometimes a group of tools are set up similarly or share a set of flags,
mixins, or other directives. You can apply a set of directives to all subtools
(recursively) of the current tool, using the
[Toys::DSL::Tool#subtool_apply](https://dazuma.github.io/toys/gems/toys-core/latest/Toys/DSL/Tool#subtool_apply-instance_method)
directive.

For example, it is common for tools to use the `:exec` built-in mixin to invoke
external programs. You can use `subtool_apply` to ensure that the mixin is
included in all subtools, so that you do not need to repeat the `include`
directive in every tool.

    subtool_apply do
      # Include the mixin only if the tool hasn't already done so
      unless include?(:exec)
        include :exec, exit_on_nonzero_status: true
      end
    end

    tool "my-tool" do
      def run
        # This tool has access to methods defined by the :exec mixin
        # because the above block is applied to the tool
        sh "echo hello"
      end
    end

Importantly, `subtool_apply` blocks are "applied" at the *end* of a tool's
definition. Therefore, when using `subtool_apply`, you have the ability to look
at the current definition of the tool to decide whether to apply further
changes. The `subtool_apply` block in the above example uses this technique; it
checks whether the `:exec` mixin has already been included before attempting to
include it. Thus, it is possible for a tool to "override" the inclusion, say,
to use a different configuration:

    tool "another-tool" do
      # Use a different configuration for the :exec mixin.
      # This "overrides" the subtool_apply block above.
      include :exec, exit_on_nonzero_status: false
      def run
        # This is run with exit_on_nonzero_status: false
        sh "echo hello"
      end
    end

### Custom acceptors

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
[Toys::DSL::Tool#acceptor](https://dazuma.github.io/toys/gems/toys-core/latest/Toys/DSL/Tool#acceptor-instance_method).

An acceptor is available to the tool in which it is defined, and any subtools
and descendants defined at the same point in the Toys search path, but not from
tools defined in a different point in the search path. For example, if you
define an acceptor in a file located in a `.toys` directory, it will be visible
to descendant tools defined in that same directory, but not in a different
`.toys` directory.

A common technique, for example, would be to define an acceptor in the index
file in a Toys directory. You can then include it from any subtools defined in
other files in that same directory.

### Controlling built-in flags

Earlier we saw that certain flags are added automatically to every tool:
`--verbose`, `--quiet`, `--help`, and so forth. You may occasionally want to
disable some of these "built-in" flags. There are two ways to do so:

If you want to use one of the built-in flags for another purpose, simply define
the flag as you choose. Flags explicitly defined by your tool take precedence
over the built-ins.

For example, normally two built-in flags are provided to decrease the verbosity
level: `-q` and `--quiet`. If you define `-q` yourself (for example to activate
a "quick" mode) then `-q` will be repurposed for your flag, but `--quiet` will
still be present to decrease verbosity.

    # Repurposes -q to set the "quick" option instead of "quiet"
    flag :quick, "-q"

You may also completely disable a flag, and *not* repurpose it, using the
`disable_flag` directive. It lets you mark one or more flags as "never use".

For example, if you disable the `-q` flag, then `-q` will no longer be a
built-in flag that decreases the verbosity, but `--quiet` will remain. To
completely disable decreasing the verbosity, disable both `-q` and `--quiet`.

    # Disables -q but leaves --quiet
    disable_flag "-q"

    # Completely disables decreasing verbosity
    disable_flag "-q", "--quiet"

### Enforcing flags before args

By default, tools allow flags and positional arguments to be interspersed when
command line arguments are parsed. This matches the behavior of most common
command line binaries.

However, some tools prefer to follow the convention that all flags must appear
first, followed by positional arguments. In such a tool, once a non-flag
argument appears on the command line, all remaining arguments are treated as
positional, even if they look like a flag and start with a hyphen.

You may configure a tool to follow this alternate parsing strategy using the
`enforce_flags_before_args` directive.

The built-in tool `toys do` is an example of a tool that does this. It
recognizes its own flags (such as `--help` and `--delim`) but once positional
arguments start appearing, it wants further flags to be treated as positional
so it can pass them down to the different steps it is executing. Here is a
simplified excerpt from the implementation that tool:

    tool "do" do
      flag :delim, default: ","
      remaining_args :commands  # the commands to execute
      enforce_flags_before_args
      def run
        # Now commands includes both the commands to run and
        # the "flags" to pass to them.
        commands.each do
          # ...
        end
      end
    end

### Requiring exact flag matches

By default, tools will recognized "shortened" forms of long flags. For example,
most suppose you are defining a tool with long flags:

    tool "my-tool" do
      flag :long_flag_name, "--long-flag-name"
      flag :another_long_flag, "--another-long-flag"
      def run
        # ...
      end
    end

When you invoke this tool, you do not need to type the entire flag names.
Abbreviations will also work:

    $ toys my-tool --long --an

As long as the abbreviation is unambiguous (i.e. there is no other flag that
begins with the same string), the Toys argument parser will recognize the flag.
This is consistent with the behavior of most command line tools (and is also
the behavior of Ruby's OptionParser library.)

However, it is possible to disable this behavior and require that flags be
presented in their entirety, using the `require_exact_flag_match` directive.

    tool "my-tool" do
      require_exact_flag_match
      flag :long_flag_name, "--long-flag-name"
      flag :another_long_flag, "--another-long-flag"
      def run
        # ...
      end
    end

Now, all flags for this tool must be presented in their entirety. Abbreviations
are not allowed.

    $ toys my-tool --long-flag-name --another-long-flag

Currently you can require exact flag matches only at the tool level, applied to
all flags for that tool. You cannot set this option for individual flags.

### Disabling argument parsing

Normally Toys handles parsing command line arguments for you. This makes
writing tools easier, and also allows Toys to generate documentation
automatically for flags and arguments. However, occasionally you'll want Toys
not to perform any parsing, but just to give you the command line arguments
raw. One common case is if your tool turns around and passes its arguments
verbatim to a subprocess.

To disable argument parsing, use the `disable_argument_parsing` directive. This
directive disables parsing and validation of flags and positional arguments.
(Thus, it is incompatible with specifying any flags or arguments for the tool.)
Instead, you can retrieve the raw arguments using the
[Toys::Context#args method](https://dazuma.github.io/toys/gems/toys-core/latest/Toys/Context#args-instance_method).

Here is an example that wraps calls to git:

    tool "my-git" do
      desc "Prints a message, and then calls git normally"
      disable_argument_parsing
      def run
        puts "Calling my-git!"
        Kernel.exec(["git"] + args)
      end
    end

### Handling interrupts

If you interrupt a running tool, say, by hitting `CTRL`-`C`, Toys will normally
terminate execution and display the message `INTERRUPTED` on the standard error
stream.

If your tool needs to handle interrupts itself, you have several options. You
can rescue the `Interrupt` exception or call `Signal.trap`. Or you can provide
an *interrupt handler* in your tool using the `on_interrupt` directive. This
directive either provides a block to handle interrupts, or designates a named
method as the handler. If an interrupt handler is present, Toys will handle
interrupts as follows:

1.  Toys will terminate the tool's `run` method by raising an `Interrupt`
    exception. Any `ensure` blocks will be called.
2.  Toys will call the interrupt handler. If this method or block takes an
    argument, Toys will pass it the `Interrupt` exception object.
3.  The interrupt handler is then responsible for tool execution from that
    point. It may terminate execution by returning or calling `exit`, or it may
    restart or resume processing (perhaps by calling the `run` method again).
    Or it may invoke the normal Toys interrupt handling (i.e. terminating
    execution, displaying the message `INTERRUPTED`) by re-raising *the same*
    interrupt exception object.
4.  If another interrupt takes place during the execution of the interrupt
    handler, Toys will terminate it by raising a *second* `Interrupt` exception
    (calling any `ensure` blocks). Then, the interrupt handler will be called
    *again* and passed the new exception. Any additional interrupts will be
    handled similarly.

Because the interrupt handler is called again even if it is itself interrupted,
you might consider detecting this case if your interrupt handler might be
long-running. You can tell how many interrupts have taken place by looking at
the `Exception#cause` property of the exception. The first interrupt will have
a cause of `nil`. The second interrupt (i.e. the interrupt raised the first
time the interrupt handler is itself interrupted) will have its cause point to
the first interrupt (which in turn has a `nil` cause.) The third interrupt's
cause will point to the second interrupt, and so on. So you can determine the
interrupt "depth" by counting the length of the cause chain.

Here is an example that performs a long-running task. The first two times the
task is interrupted, it is restarted. The third time, it is terminated.

    tool "long-running" do
      def long_task(is_restart)
        puts "task #{is_restart ? 're' : ''}starting..."
        sleep 10
        puts "task finished!"
      end

      def run
        long_task(false)
      end

      on_interrupt do |ex|
        # The third interrupt will have a non-nil ex.cause.cause.
        # At that time, just give up and re-raise the exception, which causes
        # it to propagate out and invoke the standard Toys interrupt handler.
        raise ex if ex.cause&.cause
        # Otherwise, restart the long task.
        long_task(true)
      end
    end

### Handling usage errors

Normally, if Toys detects a usage error (such as an unrecognized flag) while
parsing arguments, it will respond by aborting the tool and displaying the
usage error. It is possible to override this behavior by providing your own
usage error handler using the `on_usage_error` directive. This directive either
provides a block to handle usage errors, or designates a named method as the
handler.

If your handler block or method takes a parameter, Toys will pass it the array
of usage errors. Otherwise, you can get the array by calling
[Toys::Context#usage_errors](https://dazuma.github.io/toys/gems/toys-core/latest/Toys/Context#usage_errors-instance_method).
This array will provide you with a list of the usage errors encountered.

You can also get information about the arguments that could not be parsed from
the context. For example, the list of unrecognized flags is available from the
context key `UNMATCHED_FLAGS`.

One common technique is to redirect usage errors back to the `run` method. In
this way, `run` is called regardless of whether argument parsing succeeded or
failed.

    tool "lenient-parser" do
      flag :abc

      on_usage_error :run

      def run
        if usage_errors.empty?
          puts "Usage was correct"
        else
          puts "Usage was not correct"
        end
      end
    end

### Data files

If your tools require images, archives, keys, or other such static data, Toys
provides a convenient place to put data files that can be looked up by tools
either during definition or runtime.

To use data files, you must define your tools inside a
[Toys directory](#Toys_directories). Within the Toys directory, create a
directory named `.data` and copy your data files there.

You may then "find" a data file by providing the relative path to the file from
the `.data` directory. When defining a tool, use the
[Toys::DSL::Tool#find_data](https://dazuma.github.io/toys/gems/toys-core/latest/Toys/DSL/Tool#find_data-instance_method)
directive in a Toys file. Or, at tool execution time, call
[Toys::Context#find_data](https://dazuma.github.io/toys/gems/toys-core/latest/Toys/Context#find_data-instance_method)
(which is a convenience method for getting the tool source object using the
`TOOL_SOURCE` key, and calling
[Toys::SourceInfo#find_data](https://dazuma.github.io/toys/gems/toys-core/latest/Toys/SourceInfo#find_data-instance_method)
on it). In either case, `find_data` locates a matching file (or directory)
among the data files, and returns the full path to that file system object. You
may then read the file or perform any other operation on it.

For example, take the following directory structure:

    (current directory)
    |
    +- .toys/
       |
       +- .data/
       |  |
       |  +- greeting.txt
       |  |
       |  +- desc/
       |     |
       |     +- short.txt
       |
       +- greet.rb   <-- defines "greet" (and subtools)

The data files in `.toys/.data` are available to any tool in the `.toys`
directory or any of its subdirectories. For example, suppose we want our
"greet" tool to use the contents of `greeting.txt`. We can call `find_data` to
read those contents when the tool is executed:

    # greet.rb
    desc "Print a friendly greeting."
    optional_arg :whom, default: "world", desc: "Whom to greet."
    def run
      greeting = IO.read(find_data("greeting.txt")).strip
      puts "#{greeting}, #{whom}!"
    end

You can include directories in the argument to `find_data`. For example, here
is how to use the `find_data` directive to read the short description from the
file "desc/short.txt":

    # greet.rb
    desc IO.read(find_data("desc/short.txt")).strip
    optional_arg :whom, default: "world", desc: "Whom to greet."
    def run
      greeting = IO.read(find_data("greeting.txt")).strip
      puts "#{greeting}, #{whom}!"
    end

The `find_data` mechanism will return the "closest" file or directory found.
In the example below, there is a `desc/short.txt` file in the `.data` directory
at the top level, but there is also a `desc/short.txt` file in the `.data`
directory under `test`. Tools under the `test` directory will find the more
specific data file, while other tools will find the more general file.

    (current directory)
    |
    +- .toys/
       |
       +- .data/
       |  |
       |  +- greeting.txt
       |  |
       |  +- desc/
       |     |
       |     +- short.txt  <-- default description for all tools
       |
       +- greet.rb   <-- defines "greet" (and subtools)
       |
       +- test/
          |
          +- .data/
          |  |
          |  +- desc/
          |     |
          |     +- short.txt  <-- override description for test tools
          |
          +- unit.rb   <-- defines "test unit" (and its subtools)

If, however, you find `greeting.txt` from a tool under `test`, it will still
find the more general `.toys/.data/greeting.txt` file because there is no
overriding file under `.toys/test/.data`.

### The context directory

The **context directory** for a tool is the directory containing the toplevel
`.toys.rb` file or the `.toys` directory within which the tool is defined. It
is sometimes useful for tools that expect to be run from a specific working
directory.

For example, suppose you have a Ruby project directory:

    my-project/
    |
    +- .toys.rb  <-- project tools defined here
    |
    +- lib/
    |
    +- test/
    |
    etc...

Now suppose you defined a tool that lists the tests:

    tool "list-tests" do
      def run
        puts Dir.glob("test/**/*.rb").join("\n")
      end
    end

This tool assumes it will be run from the main project directory (`my-project`
in the above case). However, Toys lets you invoke tools even if you are in a
subdirectory:

    $ cd lib
    $ toys list-tests  # Does not work

Rake handles this by actually changing the current working directory to the
directory containing the active Rakefile. Toys, however, does not change the
working directory unless you tell it to. You can make the `list-tests` tool
work correctly by changing the directory to the context directory (which is the
directory containing the `.toys.rb` file, i.e. the `my-project` directory.)

    tool "list-tests" do
      def run
        Dir.chdir context_directory do
          puts Dir.glob("test/**/*.rb").join("\n")
        end
      end
    end

Note the context directory is different from `__dir__`. It is not necessarily
the directory containing the file being executed, but the directory containing
the entire toys directory structure. So if your tool definition is inside a
`.toys` directory, it will still work:

    my-project/   <-- context_directory still points here
    |
    +- .toys/
    |  |
    |  +- list-tests.rb   <-- tool defined here
    |
    +- lib/
    |
    +- test/
    |
    etc...

This technique is particularly useful for build tools. Indeed, all the build
tools described in the section on
[Toys as a Rake Replacement](#Toys_as_a_Rake_replacement) automatically move
into the context directory when they execute.

#### Changing the context directory

It is even possible to modify the context directory, causing tools that use the
context directory (such as the standard build tools) to run in a different
directory. Here is an example:

Suppose you have a repository with multiple gems, each in its own directory:

    my-repo/
    |
    +- .toys.rb  <-- all project tools defined here
    |
    +- gem1/
    |  |
    |  +- lib/
    |  |
    |  +- test/
    |
    +- gem2/
    |  |
    |  +- lib/
    |  |
    |  +- test/
    |
    etc...

Assuming all the gems use the same set of build tools, it is possible to define
those tools once in a single `.toys.rb` file and have it run in a particular
gem directory depending on your current location. For example, you can cd into
`gem1` or even `gem1/lib` to have the tools run on `gem1`. Because the standard
build tools execute within the context directory, you can accomplish this by
setting the context directory to the gem directory corresponding to the current
location. That is, if the working directory is `my-repo/gem1/lib`, set the
context directory to `my-repo/gem1`. Here's what that could look like:

    # .toys.rb content

    require "pathname"
    base_dir = Pathname.new context_directory
    cur_dir = Pathname.new Dir.getwd

    # The gem name is the first segment of the relative path from the context
    # directory to the current directory.
    relative_path = cur_dir.relative_path_from(base_dir).to_s
    gem_name = relative_path.split("/").first

    # Only proceed if we're truly in a subdirectory
    if gem_name && gem_name != "." && gem_name != ".."

      # Now set the context directory to the gem directory.
      set_context_directory base_dir.join(gem_name).to_s

      # Define the build tools. Each of these uses the custom context directory
      # set above, and thus runs for the selected gem.
      expand :minitest
      expand :gem_build
      # etc.
    end

### Hidden tools

Tools whose name begins with an underscore (e.g. `_foo`) are called "hidden"
tools. They can be executed the same as any other tool, but are normally
omitted from the subtool list displayed in help and usage screens. You may use
hidden tools as "internal" tools that are meant to be called only as part of
the implementation of other tools.

If you pass the `--all` flag when displaying help, the help screen will include
hidden tools in the subtools list.

## Toys administration using the system tools

Toys comes with a few built-in tools, including some that let you administer
Toys itself. These tools live in the `system` namespace.

### Getting the Toys version

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

A similar effect can of course be obtained by running `gem install toys`.

### Installing tab completion for Bash

Toys provides tab completion for the bash shell, and lets tools customize the
completions for their arguments. However, you need to install the Toys
completion tool into your shell. The following command sets up tab completion
the current shell:

    $(toys system bash-completion install)

Typically, you will want to include the above in your `.bashrc` or other bash
initialization file.

By default, this associates the Toys tab completion logic with the `toys`
executable. If you have other names or aliases for the executable, pass them as
arguments. For example, I use `t` as an alias for `toys`, and I therefore
install Toys's completion logic for `t`:

    $(toys system bash-completion install t)

You can also remove the completion logic from the current shell:

    $(toys system bash-completion remove)
    $(toys system bash-completion remove t)

At this time, bash is the only shell that is supported directly. If you are
using zsh, however, you can use the `bashcompinit` function to load the toys
bash completion (as well as other bash-based completions). This *mostly* works,
with a few caveats. Native zsh completion is on the future roadmap.

## Writing your own CLI using Toys

Although Toys is not primarily designed to help you write a custom command-line
executable, you can use it in that way. Toys is factored into two gems:
**toys-core**, which includes all the underlying machinery for creating
command-line executables, and **toys**, which is really just a wrapper that
provides the `toys` executable itself and its built-in commands and behavior.
To write your own command line executable based on the Toys system, just
require the **toys-core** gem and configure your executable the way you want.

Toys-Core is modular and lets you customize much of the behavior of a command
line executable, simply by setting options or adding plugins. For example:

*   Toys itself automatically adds a number of flags, such as `--verbose` and
    `--help`, to each tool. Toys-Core lets you customize what flags (if any)
    are automatically added for your own command line executable.
*   Toys itself provides a default way to run tools that have no `run` method.
    It assumes such tools are namespaces, and displays the online help screen.
    Toys-Core lets you provide an alternate default run method for your own
    command line executable.
*   Toys itself provides several built-in tools, such as `do`, and `system`.
    Toys-Core lets you write your own command line executable with its own
    built-in tools.
*   Toys itself implements a particular search path for user-provided Toys
    files, and looks for specific file and directory names such as `.toys.rb`.
    Toys-Core lets you change the search path, the file/directory names, or
    disable user-provided Toys files altogether for your own command line
    executable. Indeed, most command line executables do not need
    user-customizable tools, and can ship with only built-in tools.
*   Toys itself has a particular way of displaying online help and reporting
    errors. Toys-Core lets your own command line executable customize these and
    many other features.

For more information, see the
[Toys-Core documentation](https://dazuma.github.io/toys/gems/toys-core/latest/).
