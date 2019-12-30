# @title Toys-Core User Guide

# Toys-Core User Guide

Toys-Core is the command line framework underlying Toys. It implements most of
the core functionality of Toys, including the tool DSL, argument parsing,
loading Toys files, online help, subprocess control, and so forth. It can be
used to create custom command line executables using the same facilities.

If this is your first time using Toys-Core, we recommend starting with the
[README](https://dazuma.github.io/toys/gems/toys-core/latest), which includes a
tutorial that introduces how to create simple command line executables using
Toys-Core, customize the behavior, and package your executable in a gem. You
should also be familiar with Toys itself, including how to define tools by
writing Toys files, how to interpret arguments and flags, and how to use the
Toys execution environment. For background, please see the
[Toys README](https://dazuma.github.io/toys/gems/toys/latest) and
[Toys User's Guide](https://dazuma.github.io/toys/gems/toys/latest/file.guide.html).
Together, those resources will likely give you enough information to begin
creating your own basic command line executables.

This user's guide covers all the features of Toys-Core in much more depth. Read
it when you're ready to unlock all the capabilities of Toys-Core to create
sophisticated command line tools.

**(This user's guide is still under construction.)**

## Conceptual overview

Toys-Core is a command line *framework* in the traditional sense. It is
intended to be used to write custom command line executables in Ruby. The
framework provides common facilities such as argumentparsing and online help,
while your executable chooses and configures those facilities, and implements
the actual behavior.

The entry point for Toys-Core is the **cli object**. Typically your executable
script instantiates a CLI, configures it with the desired tool implementations,
and runs it.

An executable defines its functionality using the **Toys DSL** which can be
written in **toys files** or in **blocks** passed to the CLI. It uses the same
DSL used by Toys itself, and supports tools, subtools, flags, arguments, help
text, and all the other features of Toys.

An executable may customize its own facilities for writing tools by providing
**built-in mixins** and **built-in templates**, and can implement default
behavior across all tools by providing **middleware**.

Most executables will provide a set of **static tools**, but it is possible to
support user-provided tools as Toys does. Executables can customize how tool
definitions are searched and loaded from the file system.

Finally, an executable may customize many aspects of its behavior, such as the
**logging output**, **error handling**, and even shell **tab completion**.

## Using the CLI object

The CLI object is the main entry point for Toys-Core. Most command line
executables based on Toys-Core use it as follows:

 *  Instantiate a CLI object, passing configuration parameters to the
    constructor.
 *  Define the functionality of the CLI, either inline by passing it blocks, or
    by providing paths to tool files.
 *  Call the {Toys::CLI#run} method, passing it the command line arguments
    (e.g. from `ARGV`).
 *  Handle the result code, normally by passing it to `Kernel#exit`.

Following is a simple "hello world" example using the CLI:

    #!/usr/bin/env ruby

    require "toys-core"

    # Instantiate a CLI with the default options
    cli = Toys::CLI.new

    # Define the functionality
    cli.add_config_block do
      desc "My first executable!"
      flag :whom, default: "world"
      def run
        puts "Hello, #{whom}!"
      end
    end

    # Run the CLI, passing the command line arguments
    result = cli.run(*ARGV)

    # Handle the result code.
    exit(result)

### CLI execution

This section provides some detail on how a CLI executes your code.

(TODO)

### Configuring the CLI

Generally, you control CLI features by passing arguments to its constructor.
These features include:

 *  How to find toys files and related code and data. See the section on
    [writing tool files](#Writing_tool_files).
 *  Middleware, providing common behavior for all tools. See the section on
    [customizing the middleware stack](#Customizing_default_behavior).
 *  Common mixins and templates available to all tools. See the section on
    [how to define mixins and templates](#Defining_mixins_and_templates).
 *  How logs and errors are reported. See the section on
    [customizing tool output](#Customizing_tool_output).
 *  How the executable interacts with the shell, including setting up tab
    completion. See the
    [corresponding section](#Shell_and_command_line_integration).

Each of the actual parameters is covered in detail in the documentation for
{Toys::CLI#initialize}. The configuration of a CLI cannot be changed once the
CLI is constructed. If you need to a CLI with a modified configuration, use
{Toys::CLI#child}.

## Defining functionality

### Writing tools in blocks

### Writing tool files

### Tool priority

### Defining mixins and templates

## Customizing tool output

### Logging and verbosity

### Handling errors

## Customizing default behavior

### Introducing middleware

### Built-in middlewares

### Writing your own middleware

## Shell and command line integration

### Interpreting tool names

### Tab completion

## Packaging your executable
