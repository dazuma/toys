<!--
# @title Toys-Core User Guide
-->

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

Toys-Core is a **command line framework** in the traditional sense. It is
intended to be used to write custom command line executables in Ruby. The
framework provides common facilities such as argument parsing and online help,
while your executable chooses and configures those facilities, and implements
the actual behavior.

The entry point for Toys-Core is the **cli object**. Typically your executable
script instantiates a CLI, configures it with the desired tool implementations,
and runs it.

An executable defines its functionality using the **Toys DSL** which can be
written in **toys files** or in **blocks** passed to the CLI. It uses the same
DSL used by Toys itself, and supports tools, subtools, flags, arguments, help
text, and all the other features of Toys.

An executable can customize its own facilities for writing tools by providing
**built-in mixins** and **built-in templates**, and can implement default
behavior across all tools by providing **middleware**.

Most executables will provide a set of **static tools**, but it is possible to
support user-provided tools as Toys does. Executables can customize how tool
definitions are searched and loaded from the file system.

Finally, an executable can customize many aspects of its behavior, such as the
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

When you call {Toys::CLI#run}, the CLI runs through three phases:

 *  **Loading** in which the CLI identifies which tool to run, and loads the
    tool from a tool **source**, which could be a block passed to the CLI, or a
    file loaded from the file system, git, or other location.
 *  **Building context**, in which the CLI parses the command-line arguments
    according to the flags and arguments declared by the tool, instantiates the
    tool, and populates the {Toys::Context} object (which is `self` when the
    tool is executed)
 *  **Execution**, which involves running any initializers defined on the tool,
    applying middleware, running the tool, and handling errors.

#### The Loader

When the CLI needs the definition of a tool, it queries the {Toys::Loader}. The
loader object is configured with a set of tool _sources_ representing ways to
define a tool. These sources may be blocks passed directly to the CLI,
directories and files in the file system, and remote git repositories. When a
tool is requested by name, the loader is responsible for locating the tool
definition in those sources, and constructing the tool definition object,
represented by {Toys::ToolDefinition}.

One important property of the loader is that it is _lazy_. It queries tool
sources only if it has reason to believe that a tool it is looking for may be
defined there. For example, if your tools are defined in a directory structure,
the `foo bar` tool might live in the file `foo/bar.rb`. The loader will open
that file, if it exists, only when the `foo bar` tool is requested. If instead
`foo qux` is requested, the `foo/bar.rb` file is never even opened.

Perhaps more subtly, if you call {Toys::CLI#add_config_block} to define tools,
the block is stored in the loader object _but not called immediately_. Only
when a tool is requested does the block actually execute. Furthermore, if you
have `tool` blocks inside the block, the loader will execute only those that
are relevant to a tool it wants. Hence:

    cli.add_config_block do
      tool "foo" do
        def run
          puts "foo called"
        end
      end

      tool "bar" do
        def run
          puts "bar called"
        end
      end
    end

If only `foo` is requested, the loader will execute the `tool "foo" do` block
to get that tool definition, but will not execute the `tool "bar" do` block.

We will discuss more about the features of the loader below in the section on
[defining functionality](#Defining_functionality).

#### Building context

Once a tool is defined, the CLI prepares it for execution by building a
{Toys::Context} object. This object is `self` during tool runtime, and it
includes:

 *  The tool's methods, including its `run` entrypoint method.
 *  Access to core tool functionality such as exit codes and logging.
 *  The results from parsing the command line arguments
 *  The runtime environment, including the tool's name, where the tool was
    defined, detailed results from argumet parsing, and so forth.

Much of this information is stored in a data hash, whose keys are defined as
constants under {Toys::Context::Key}.

Argument parsing is directed by the {Toys::ArgParser} class. This class, for
the most part, replicates the semantics of the standard Ruby OptionParser
class, but it implements a few extra features and cleans up a few ambiguities.

#### Tool execution and error handling

The execution phase involves:

 *  Running the tool's initializers, if any, in order.
 *  Running the tool's middleware. Each middleware "wraps" the execution of
    subsequent middleware and the final tool execution, and has the opportunity
    to inject functionality before and after the main execution, or even to
    forgo or replace the main functionality, similar to Rack middleware.
 *  Executing the tool itself by calling its `run` method.

During execution, exceptions are caught and reported along with the location in
the tool source where it was triggered. This logic is handled by the
{Toys::ContextualError} class.

The CLI can be configured with an error handler that responds to any exceptions
raised during execution. An error handler is simply a callable object (such as
a `Proc`) that takes an exception as an argument. The provided
{Toys::CLI::DefaultErrorHandler} class provides the default behavior of the
normal `toys` CLI, but you can provide any object that duck types the `call`
method.

#### Multiple runs

The {Toys::CLI} object can be reused to run multiple tools. This may save on
loading overhead, as the tools can be loaded just once and their definitions
reused for multiple executions. It can even perform multiple executions
concurrently in separate threads, assuming the tool implementations themselves
are thread-safe.

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
CLI is constructed. If you need a CLI with modified configuration, use
{Toys::CLI#child}, which creates a _copy_ of the CLI with any modifications you
request.

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

## Overview of Toys-Core classes