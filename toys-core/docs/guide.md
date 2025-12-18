<!--
# @title Toys-Core User Guide
-->

# Toys-Core User Guide

Toys-Core is the command line framework underlying
[Toys](https://dazuma.github.io/toys/gems/toys/latest). It implements most of
the core functionality of Toys, including the tool DSL, argument parsing,
loading Toys files, online help, subprocess control, and so forth. Toys-Core
can be used to create custom command line executables, or it can be used to
provide mixins or templates in your gem to help your users define tools related
to your gem's functionality.

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
intended as the core component of the Toys gem, but is designed generically for
writing custom command line executables in Ruby. The framework provides common
facilities such as argument parsing and online help. Your executable can then
choose and configure those facilities, and implement the actual behavior.

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
support user-provided tools as Toys does. Executables can customize how such
tool definitions are searched and loaded from the file system.

An executable can customize many aspects of its behavior, such as the
**logging output**, **error handling**, and even shell **tab completion**.

Finally, Toys-Core can also be used to publish **Toys extensions**, collections
of mixins, templates, and/or predefined tools that can be distributed as gems
to enhance Toys for other users.

## Using the CLI object

The {Toys::CLI} object is the main entry point for Toys-Core. Most command line
executables based on Toys-Core use it as follows:

 *  Instantiate a CLI object, passing configuration parameters to the
    {Toys::CLI#initialize constructor}.
 *  Define the functionality of the CLI, either inline by passing it blocks, or
    by providing paths to tool files.
 *  Call the {Toys::CLI#run} method, passing it the command line arguments
    (e.g. from `ARGV`).
 *  Handle the result code, normally by passing it to `Kernel#exit`.

To get access to the CLI object, or any other Toys-Core classes, you first need
to ensure that the `toys-core` gem is loaded, and `require "toys-core"`.

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
 *  **Context building**, in which the CLI parses the command-line arguments
    according to the flags and arguments declared by the tool, instantiates the
    tool, and populates the {Toys::Context} object (which is `self` when the
    tool is executed)
 *  **Execution**, which involves running any initializers defined on the tool,
    applying middleware, running the tool's code, and handling errors.

#### The Loader

When the CLI needs the definition of a tool, it queries the {Toys::Loader}. The
loader object is configured with a set of tool _sources_ representing ways to
define a tool. These sources may be blocks passed directly to the CLI, or
directories and files loaded from the file system, from gems, or even from
remote git repositories. When a tool is requested by name, the loader is
responsible for locating the tool definition in those sources, and constructing
the tool definition object, represented by {Toys::ToolDefinition}.

One important property of the loader is that it is _lazy_. It queries tool
sources only when it has reason to believe that a tool it is looking for may be
defined there. For example, if your tools are defined in a directory structure,
a tool named `foo bar` might live in the file `foo/bar.rb`. The loader will
open that file, if it exists, only when the `foo bar` tool is requested. If
instead `foo qux` is requested, the `foo/bar.rb` file is never even opened.

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
[defining functionality](#defining-functionality).

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

 *  Running the tool's initializers (if any) in order.
 *  Running the tool's middleware. Each middleware "wraps" the execution of
    subsequent middleware and the final tool execution, and has the opportunity
    to inject functionality before and after the main execution, or even to
    forgo or replace the main functionality, similar to Rack middleware.
 *  Executing the tool itself by calling its `run` method.

The CLI also implements error and signal handling, directing control either to
the tool's callbacks or to fallback handlers that can be configured into the
CLI itself. More on this later.

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
    [defining functionality](#defining-functionality).
 *  Middleware, providing common behavior for all tools. See the section on
    [customizing the middleware stack](#customizing-default-behavior).
 *  Common mixins and templates available to all tools. See the section on
    [how to define mixins and templates](#defining-mixins-and-templates).
 *  How logs, errors, and signals are reported. See the section on
    [customizing tool output](#customizing-tool-output).
 *  How the executable interacts with the shell, including setting up tab
    completion. See the
    [corresponding section](#shell-and-command-line-integration).

Each of the actual parameters is covered in detail in the documentation for
{Toys::CLI#initialize}. The configuration of a CLI cannot be changed once the
CLI is constructed. If you need a CLI with modified configuration, use
{Toys::CLI#child}, which creates a _copy_ of the CLI with any modifications you
request.

## Defining functionality

Toys-Core uses (and indeed, provides the underlying implementation of) the
familiar Toys DSL that you can read about in the
[Toys README](https://dazuma.github.io/toys/gems/toys/latest) and
[Toys User's Guide](https://dazuma.github.io/toys/gems/toys/latest/file.guide.html).
This section assumes familiarity with those techniques for defining tools.

Here we will cover how to use the Toys-Core interfaces to point to specific
tool definition files or to load tool definitions programmatically. We'll also
look more closely at how tool definition works, providing insights into lazy
loading and the tool prioritization system.

### Writing tools in blocks

If you are writing your own command line executable using Toys-Core, often the
easiest way to define your tools is to use a block. The "hello world" example
at the start of this guide uses this technique:

    #!/usr/bin/env ruby

    require "toys-core"

    cli = Toys::CLI.new

    # Define the functionality by passing a block to the CLI
    cli.add_config_block do
      desc "My first executable!"
      flag :whom, default: "world"
      def run
        puts "Hello, #{whom}!"
      end
    end

    result = cli.run(*ARGV)
    exit(result)

The block simply contains Toys DSL syntax. The above example configures the
"root tool", that is, the functionality of the program if you do not pass a
tool name on the command line. You can also include "tool" blocks to define
named tools and subtools, just as you would in a normal Toys file.

The reference documentation for {Toys::CLI#add_config_block} lists several
options that can be passed in. `:context_directory` lets you select a context
directory for tools defined in the block. Normally, this is the directory
containing the Toys files in which the tool is defined, but when tools are
defined in a block, it must be set explicitly. (Otherwise, calling the
`context_directory` from within the tool will return `nil`.) Similarly, the
`:source_name`, normally the path to the Toys file that appears in error
messages and documentation, can also be set explicitly.

### Writing tool files

If you want to define tools in separate files, you can do so and pass the file
paths to the CLI using {Toys::CLI#add_config_path}.

    #!/usr/bin/env ruby

    require "toys-core"

    cli = Toys::CLI.new

    # Load a file defining the functionality
    cli.add_config_path("/usr/local/share/my_tool.rb")

    result = cli.run(*ARGV)
    exit(result)

The contents of `/usr/local/share/my_tool.rb` could then be:

    desc "My first executable!"
    flag :whom, default: "world"
    def run
      puts "Hello, #{whom}!"
    end

You can point to a specific file to load, or to a Toys directory, whose
contents will be loaded similarly to how a `.toys` directory is loaded.

The CLI also provides high-level lookup methods that search for files named
`.toys.rb` or directories named `.toys`. (These names can also be configured
by passing appropriate options to the CLI constructor.) These methods,
{Toys::CLI#add_search_path} and {Toys::CLI#add_search_path_hierarchy},
implement the actual behavior of Toys in which it looks for any available files
in the current directory or its parents.

### Tool priority

It is possible to configure a CLI with multiple files, directories, and/or
blocks with tool definitions. Indeed, this is how the `toys` gem itself is
configured: loading tools from the current directory and its ancestry, from
global directories, and from builtins. When a CLI is configured to load tools
from multiple sources, it combines them. However, if multiple sources define a
tool of the same name, only one definition will "win", the one from the source
with the highest priority.

Each time a tool source is added to a CLI using {Toys::CLI#add_config_block},
{Toys::CLI#add_config_path}, or similar, that new source is added to a
prioritized list. By default it is added to the end of the list, at a lower
priority level than previously added sources. Thus, any tools defined in the
new source would be overridden by tools of the same name defined in previously
added sources.

    #!/usr/bin/env ruby

    require "toys-core"

    cli = Toys::CLI.new

    # Add a block defining a tool called "hello"
    cli.add_config_block do
      tool "hello" do
        def run
          puts "Hello from the first config block!"
        end
      end
    end

    # Add a lower-priority block defining a tool with the same name
    cli.add_config_block do
      tool "hello" do
        def run
          puts "Hello from the second config block!"
        end
      end
    end

    # Runs the tool defined in the first block
    result = cli.run("hello")
    exit(result)

When defining tool blocks or loading tools from files, you can also add the new
source at the *front* of the priority list by passing an argument:

    # Add tools with the highest priority
    cli.add_config_block high_priority: true do
      tool "hello" do
        def run
          puts "Hello from the second config block!"
        end
      end
    end

Priorities are used by the `toys` gem when loading tools from different
directories. Any `.toys.rb` file or `.toys` directory is added to the CLI at
the front of the list, with the highest priority. Parent directories are added
at subsequently lower priorities, and common directories such as the home
directory are loaded at the lowest priority.

### Customizing built-in mixins and templates

Mixins and templates are two of the most useful mechanisms for sharing code and
generating code for tools. In the main Toys gem, a certain set of mixins are
built-in and can be referenced via symbols. For example, the *exec* mixin that
provides facilities for running and controlling external processes, can be
included using `include :exec`. In this section, we see how to define your own
"built-in" mixins and templates that can be referenced via symbol.

"Built-in" mixins and templates (and middleware, which we shall cover later)
are provided via the {Toys::ModuleLookup} mechanism. ModuleLookup lets you
select a directory for "standard" instances. By default, Toys-Core establishes
the `toys/standard_mixins` directory in the gem as the standard directory for
mixins, and whenever you reference a mixin by symbol, it is used to determine
the name of a file to open and the name of a module to load. You can, however,
change this directory and provide a different ModuleLookup when constructing a
CLI object.

Suppose, for example, you are writing a gem `my_tools` that uses Toys-Core, and
you have a directory in your gem's `lib` called `my_tools/mixins` where you
want your standard mixins to live. You could define mixins there:

    # This file is my_tools/mixins/foo_mixin.rb

    require "toys-core"

    module MyTools
      module Mixins
        module FooMixin
          include Toys::Mixin

          def foo
            puts "Foo was called"
          end
        end
      end
    end

Here is how you could configure a CLI to load standard mixins from that
directory, and then use the above mixin.

    # This file is my_tools.rb

    require "toys-core"

    my_mixin_lookup = Toys::ModuleLookup.new.add_path("my_tools/mixins")
    cli = Toys::CLI.new(mixin_lookup: my_mixin_lookup)

    cli.add_config_block do
      def run
        include :foo_mixin
        foo
      end
    end

When you configure a ModuleLookup, you provide one or more paths, which are
path prefixes that are used in a `require` statement. In the above example,
we used the path `my_tools/mixins` for the ModuleLookup. Now when the CLI uses
this ModuleLookup to find a mixin called `:foo_mixin`, it will attempt to
`require "my_tools/mixins/foo_mixin"`, which matches the file where we defined
our mixin.

Notice also that `foo_mixin.rb` above defines FooMixin within a specific module
hierarchy, corresponding to the file name `my_tools/mixins/foo_mixin.rb`
according to standard Ruby naming conventions. The fully-qualified module name
for the mixin must match this expected name, constructed from the path provided
to the ModuleLookup and the name of the mixin. You can change the way this name
mapping occurs, by providing the `:module_base` argument to the ModuleLookup
constructor.

Template lookup happens similarly. Toys-Core does not provide a set of default
templates, but the Toys gem does; the `StandardCLI` class used by Toys sets the
`:template_lookup` to point to the `toys/templates` directory in that gem's
library. If you want to customize the default template lookup for your
Toys-based library, you can similarly provide your own ModuleLookup. This will
let you control how templates are resolved when specified by symbol.

## Customizing diagnostic output

Toys provides diagnostic logging and error reporting that can be customized by
the CLI. This section explains how to control logging output and levels, and
how to customize signal handling and exception reporting.

Toys-Core provides a class called {Toys::Utils::StandardUI} that implements the
diagnostic output format used by the `toys` gem. We'll look at how to use the
StandardUI after discussing each type of diagnostic output.

### Logging

Toys provides a Logger for each tool execution. Tools can access this Logger by
calling the `logger` method, or by getting the `Toys::Context::Key::LOGGER`
context object.

    #!/usr/bin/env ruby

    require "toys-core"

    cli = Toys::CLI.new

    cli.add_config_block do
      tool "hello" do
        def run
          logger.info "This log entry is displayed in verbose mode."
        end
      end
    end

    result = cli.run(*ARGV)
    exit(result)

#### Log level and verbosity

The logging level is controlled by the *verbosity* setting when the tool is
invoked. This built-in attribute starts at 0, and by convention can be
increased or decreased by the user by passing the `--verbose` or `--quiet`
flags. (These flags are not provided by the CLI itself, but are implemented by
*middleware*, which we will cover later.) Its final setting is then mapped to a
Logger level threshold.

By default, a verbosity of 0 maps to log level `Logger::WARN`. Entries logged
at level `Logger::WARN` or higher are displayed, whereas entries logged at
`Logger::INFO` or `Logger::DEBUG` are suppressed. If the user increases the
verbosity by passing `--verbose` or `-v`, a verbosity of 1 will move the log
level threshold down to `Logger::INFO`.

You can modify the *starting* verbosity value by passing it to {Toys::CLI#run}.
Passing `verbosity: 1` will set the starting verbosity to 1, meaning
`Logger::INFO` entries will display but `Logger::DEBUG` entries will not. If
the invoker then provides an extra `--verbose` flag, the verbosity will further
increase to 2, allowing `Logger::DEBUG` entries to appear.

    # ...
    result = cli.run(*ARGV, verbosity: 1)
    exit(result)

You can also modify the log level that verbosity 0 maps to by passing the
`base_level` argument to the CLI constructor. The following causes verbosity 0
to map to `Logger::INFO` rather than `Logger::WARN`.

    cli = Toys::CLI.new(base_level: Logger::INFO)

#### Customizing the logger

Toys-Core configures its default logger with the default logging formatter, and
configures it to log to STDERR. If you want to change any of these settings,
you can provide your own logger by passing a `logger` to the CLI constructor
constructor.

    my_logger = Logger.new("my_logfile.log")
    cli = Toys::CLI.new(logger: my_logger)

A logger passed directly to the CLI is *global*. The CLI will attempt to use it
for every execution, even if multiple executions are happening concurrently. In
the concurrent case, this might cause problems if those executions attempt to
use different verbosity settings, as the log level thresholds will conflict. If
your CLI might be run multiple times concurrently, we recommend instead passing
a `logger_factory` to the CLI constructor. This is a Proc that will be invoked
to create a new logger for each execution.

    my_logger_factory = Proc.new do
      Logger.new("my_logfile.log")
    end
    cli = Toys::CLI.new(logger_factory: my_logger_factory)

#### StandardUI logging

{Toys::Utils::StandardUI} implements the logger used by the `toys` gem, which
formats log entries with the severity and timestamp using ANSI coloring.

You can use this logger by passing {Toys::Utils::StandardUI#logger_factory} to
the CLI constructor:

    standard_ui = Toys::Utils::StandardUI.new
    cli = Toys::CLI.new(logger_factory: standard_ui.logger_factory)

You can also customize the logger by subclassing StandardUI and overriding its
methods or adjusting its parameters. In particular, you can alter the
{Toys::Utils::StandardUI#log_header_severity_styles} mapping to adjust styling,
or override {Toys::Utils::StandardUI#logger_factory_impl} or
{Toys::Utils::StandardUI#logger_formatter_impl} to adjust content and
formatting.

### Handling errors

If an unhandled exception (specifically an exception represented by a subclass
of `StandardError` or `ScriptError`) occurs, or a signal such as an interrupt
(represented by a `SignalException`) is received, during tool execution,
Toys-Core first wraps the exception in a {Toys::ContextualError}. This error
type provides various context fields such as an estimate of where in the tool
source the error may have occurred. It also provides the original exception in
the `cause` field.

Then, Toys-Core invokes the error handler, a Proc that you can set as a
configuration argument when constructing a CLI. An error handler takes the
{Toys::ContextualError} wrapper as an argument and should perform any desired
final handling of an unhandled exception, such as displaying the error to the
terminal, or reraising the exception. The handler should then return the
desired result code for the execution.

    my_error_handler = Proc.new |wrapped_error| do
      # Propagate signals out and let the Ruby VM handle them.
      raise wrapped_error.cause if wrapped_error.cause.is_a?(SignalException)
      # Handle any other exception types by printing a message.
      $stderr.puts "An error occurred. Please contact your administrator."
      # Return the result code
      255
    end
    cli = Toys::CLI.new(error_handler: my_error_handler)

If you do not set an error handler, the exception is raised out of the
{Toys::CLI#run} call. In the case of signals, the *cause*, represented by a
`SignalException`, is raised directly so that the Ruby VM can handle it
normally. For other exceptions, however, the {Toys::ContextualError} wrapper
will be raised so that a rescue block has access to the context information.

#### StandardUI error handling

{Toys::Utils::StandardUI} provides the error handler used by the `toys` gem.
For normal exceptions, this standard handler displays the exception to STDERR,
along with some contextual information such as the tool name and arguments and
the location in the tool source where the error occurred, and returns an
appropriate result code, typically 1. For signals, this standard handler
displays a brief message noting the signal or interrupt, and returns the
conventional result code of `128 + signo` (e.g. 130 for interrupts).

You can use this error handler by passing
{Toys::Utils::StandardUI#error_handler} to the CLI constructor:

    standard_ui = Toys::Utils::StandardUI.new
    cli = Toys::CLI.new(error_handler: standard_ui.error_handler)

You can also customize the error handler by subclassing StandardUI and
overriding its methods. In particular, you can alter what is displayed in
response to errors or signals by overriding 
{Toys::Utils::StandardUI#display_error_notice} or
{Toys::Utils::StandardUI#display_signal_notice}, respectively, and you can
alter how exit codes are generated by overriding
{Toys::Utils::StandardUI#exit_code_for}.

#### Nonstandard exceptions

Toys-Core error handling handles normal exceptions that are subclasses of
`StandardError`, errors coming from Ruby file loading and parsing that are
subclasses of `ScriptError`, and signals that are subclasses of
`SignalException`.

Other exceptions such as `NoMemoryError` or `SystemStackError` are not handled
by Toys, and are raised directly out of the {Toys::CLI#run}.

## Customizing default behavior

Command line tools often have a set of common behaviors, such as online help,
flags that control verbosity, and handlers for option parsing errors and corner
cases. In Toys-Core, a few of these common behaviors are built into the CLI
class as described above, but others are implemented and configured using
**middleware**.

Toys Middleware is analogous to middleware in other frameworks. It is code that
"wraps" tools defined in a Toys CLI and makes modifications. Middleware can,
for example, modify the tool's properties such as its description or settings,
modify the arguments accepted by the tool, and/or modify the execution of the
tool, by injecting code before and/or after the tool's execution, or even
replacing the execution altogether.

### Introducing middleware

A middleware object must duck-type {Toys::Middleware}, although it does not
necessarily need to include the module itself. {Toys::Middleware} defines two
methods, {Toys::Middleware#config} and {Toys::Middleware#run}. The first is
is called after a tool is defined, and lets the middleware modify the tool's
definition, e.g. to modify or provide defaults for properties such as
description and common flags. The second is called when a tool is executed, and
lets the middleware modify the tool's execution.

Middleware is arranged in a stack, where each middleware object "wraps" the
objects below it. Each middleware object's methods can implement its own
functionality, and then either pass control to the next middleware in the
stack, or stop processing and disable the rest of the stack. In particular, if
a middleware stops processing during the {Toys::Middleware#run} call, the
normal tool execution is also canceled; hence, middleware can even be used to
replace normal tool execution.

### Configuring middleware

Middleware is normally configured as part of the CLI object. Each CLI includes
an ordered list, a _stack_, of middleware specifications, each represented by
{Toys::Middleware::Spec}. A middleware spec can reference a specific middleware
object, a class to instantiate, or a name that can be looked up from a
directory of middleware class files. You can pass an array of these specs to a
CLI object when you instantiate it.

A useful example can be seen in the default Toys CLI behavior. If you do not
provide a middleware stack when instantiating {Toys::CLI}, the class uses a
default stack that looks approximately like this:

    [
      Toys::Middleware.spec(:set_default_descriptions),
      Toys::Middleware.spec(:show_help, help_flags: true, fallback_execution: true),
      Toys::Middleware.spec(:handle_usage_errors),
      Toys::Middleware.spec(:add_verbosity_flags),
    ]

Each of the names, e.g. `:set_default_descriptions`, is the name of a Ruby
file in the `toys-core` gem under `toys/standard_middleware`. You can configure
the middleware system to recognize middleware by name, by providing a
middleware lookup object, of type {Toys::ModuleLookup}. This object is
configured with one or more directories, and if you provide a name, it looks
for an appropriate module of that name in a ruby file in those directories. By
default, the middleware lookup in {Toys::CLI} looks for middleware in the
`toys/standard_middleware` directory in the `toys-core` gem, but you can
configure it to look elsewhere.

Note also that, in the case of `:show_help`, the stack above also includes some
options that are passed to the {Toys::StandardMiddleware::ShowHelp} middleware
constructor when it is instantiated.

You can also look at the middleware stack in the `Toys::StandardCLI` class in
the `toys` gem to see the middleware as the `toys` executable configures it.

### Built-in middlewares

The `toys-core` gem provides several useful middleware classes that you can use
when configuring your own CLI. These live in the `toys/standard_middlware`
directory, and are available by name if you keep the default middleware lookup.
These built-in middlewares include:

 *  {Toys::StandardMiddleware::AddVerbosityFlags} which adds the `--verbose`
    and `--quiet` flags that control verbosity.
 *  {Toys::StandardMiddleware::ApplyConfig} which is instantiated with a block,
    and includes that block when configuring all tools.
 *  {Toys::StandardMiddleware::HandleUsageErrors} which provides a standard
    behavior for handling usage errors. That is, it catches
    {Toys::ArgParsingError} and outputs the error along with usage info.
 *  {Toys::StandardMiddleware::SetDefaultDescriptions} which provides defaults
    for tool description and long description fields. It can handle various
    kinds of tools, including normal tools, namespaces, the root tool, and
    delegates.
 *  {Toys::StandardMiddleware::ShowHelp} which adds help flags (e.g. `--help`)
    to tools, and responds by showing the help page.
 *  {Toys::StandardMiddleware::ShowRootVersion} which displays a version string
    when the root tool is invoked with `--version`.

### Writing your own middleware

Writing your own middleware is as simple as writing a class that implements the
{Toys::Middleware#config} and/or {Toys::Middleware#run} methods. The middleware
class need not include the {Toys::Middleware} module; it merely needs to
duck-type at least one of its methods. Your class can then be used in the stack
of middleware specifications.

#### Example: TimingMiddleware

An example would probably do best to illustrate how to write middleware. The
following is a simple middleware that adds the `--show-timing` flag to every
tool. When the flag is set, the middleware displays how long the tool took to
execute.

    class TimingMiddleware
      # This is a context key that will be used to store the "--show-timing"
      # flag state. We can use `Object.new` to ensure that the key is unique
      # across other middlewares and tool definitions.
      KEY = Object.new.freeze

      # This method intercepts tool configuration. We use it to add a flag that
      # enables timing display.
      def config(tool, _loader)
        # Add a flag to control this functionality. Suppress collisions, i.e.
        # just silently do nothing if the tool has already added a flag called
        # "--show-timing".
        tool.add_flag(KEY, "--show-timing", report_collisions: false)

        # Calling yield passes control to the rest of the middleware stack.
        # Normally you should call yield, to ensure that the remaining
        # middleware can run. If you omit this, no additional middleware will
        # be able to run tool configuration. Note you can also perform
        # additional processing after the yield call, i.e. after the rest of
        # the middleware stack has run.
        yield
      end

      # This method intercepts tool execution. We use it to collect timing
      # information, and display it if the flag has been provided in the
      # command line arguments.
      def run(context)
        # Read monotonic time at the start of execution.
        start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        # Call yield to run the rest of the middleware stack, including the
        # actual tool execution. If you omit this, you will prevent the rest of
        # the middleware stack, AND the actual tool execution, from running.
        # So you could omit the yield call if your goal is to replace tool
        # execution with your own code.
        yield

        # Read monotonic time again after execution.
        end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        # Display the elapsed time, if the tool was passed the "--show-timing"
        # flag.
        puts "Tool took #{end_time - start_time} secs" if context[KEY]
      end
    end

We can now insert our middleware into the stack when we create a CLI. Here
we'll take that "default" stack we saw earlier and add our timing middleware at
the top of the stack. We put it here so that its execution "wraps" all the
other middleware, and thus its timing measurement includes the latency incurred
by other middleware (including middleware that replaces execution such as
`:show_help`).

    my_middleware_stack = [
      Toys::Middleware.spec(TimingMiddleware),
      Toys::Middleware.spec(:set_default_descriptions),
      Toys::Middleware.spec(:show_help, help_flags: true, fallback_execution: true),
      Toys::Middleware.spec(:handle_usage_errors),
      Toys::Middleware.spec(:add_verbosity_flags),
    ]
    cli = Toys::CLI.new(middleware_stack: my_middleware_stack)

Now, every tool run by this CLI wil have the `--show-timing` flag and
associated functionality.

## Shell and command line integration

(TODO)

### Interpreting tool names

(TODO)

### Tab completion

(TODO)

## Packaging your executable

(TODO)

## Extending Toys

(TODO)

## Overview of Toys-Core classes

(TODO)
