# frozen_string_literal: true

require "logger"

module Toys
  ##
  # A Toys-based CLI.
  #
  # This is the entry point for command line execution, and the stable public
  # interface to the framework. A CLI owns the configuration: it gathers all
  # the settings in one place, constructs the {Toys::Loader} that finds and
  # loads tool definitions, and constructs the {Toys::Runner} that runs them.
  # It also provides {#child}, which clones the configuration so a tool can be
  # run under modified settings.
  #
  # Running a tool is delegated to the Runner; {#run} and {#load_tool} are thin
  # wrappers around it that supply the CLI's configuration.
  #
  # This is the class to instantiate to create a Toys-based command line
  # executable. For example:
  #
  #     #!/usr/bin/env ruby
  #     require "toys-core"
  #     cli = Toys::CLI.new
  #     cli.add_config_block do
  #       def run
  #         puts "Hello, world!"
  #       end
  #     end
  #     exit(cli.run(*ARGV))
  #
  # The currently running CLI is also available at runtime, and can be used by
  # tools that want to invoke other tools. For example:
  #
  #     # My .toys.rb
  #     tool "foo" do
  #       def run
  #         puts "in foo"
  #       end
  #     end
  #     tool "bar" do
  #       def run
  #         puts "in bar"
  #         cli.run "foo"
  #       end
  #     end
  #
  class CLI
    ##
    # Create a CLI.
    #
    # Most configuration parameters (besides tool definitions and tool lookup
    # paths) are set as options passed to the constructor. These options fall
    # roughly into four categories:
    #
    #  *  Options affecting output behavior:
    #      *  `logger`: A global logger for all tools to use
    #      *  `logger_factory`: A proc that returns a logger to use
    #      *  `base_level`: The default log level
    #      *  `error_handler`: Callback for handling exceptions
    #      *  `executable_name`: The name of the executable
    #  *  Options affecting tool specification
    #      *  `extra_delimiters`: Tool name delimiters besides space
    #      *  `completion`: Tab completion handler
    #  *  Options affecting tool definition
    #      *  `middleware_stack`: The middleware applied to all tools
    #      *  `mixin_lookup`: Where to find well-known mixins
    #      *  `middleware_lookup`: Where to find well-known middleware
    #      *  `template_lookup`: Where to find well-known templates
    #  *  Options affecting tool files and directories
    #      *  `config_dir_name`: Directory name containing tool files
    #      *  `config_file_name`: File name for tools
    #      *  `index_file_name`: Name of index files in tool directories
    #      *  `preload_file_name`: Name of preload files in tool directories
    #      *  `preload_dir_name`: Name of preload directories in tool directories
    #      *  `data_dir_name`: Name of data directories in tool directories
    #
    # @param logger [Logger] A global logger to use for all tools. This can be
    #     set if the CLI will call at most one tool at a time. However, it will
    #     behave incorrectly if the CLI might run multiple tools concurrently
    #     with different verbosity settings (since the logger cannot have
    #     multiple level settings simultaneously). In that case, do not set a
    #     global logger, but use the `logger_factory` parameter instead.
    # @param logger_factory [Proc] A proc that takes a {Toys::ToolDefinition}
    #     as an argument, and returns a `Logger` to use when running that tool.
    #     Optional. If not provided (and no global logger is set),
    #     {Toys::CLI.default_logger_factory} is called to get a basic default.
    # @param base_level [Integer] The logger level that should correspond
    #     to zero verbosity.
    #     Optional. If not provided, defaults to the level the logger has
    #     before a run adjusts it (which is often `Logger::WARN`). See the
    #     same argument to {Toys::Runner#initialize} for how this interacts
    #     with nested runs.
    # @param error_handler [Proc,nil] A proc that is called when an unhandled
    #     exception is detected. See the `error_handler` argument to
    #     {Toys::Runner#initialize} for the handler's contract. Because a CLI
    #     always wraps errors, a handler installed here sees only a
    #     {Toys::ContextualError} or a bare `SignalException`.
    #     Optional. If not provided, {Toys::CLI.default_error_handler} is
    #     called to get a basic default handler that reraises the exception.
    # @param executable_name [String] The executable name displayed in help
    #     text. Optional. Defaults to the ruby program name.
    #
    # @param extra_delimiters [String] A string containing characters that can
    #     function as delimiters in a tool name. Defaults to empty. Allowed
    #     characters are period, colon, and slash.
    # @param completion [Toys::Completion::Base] A specifier for shell tab
    #     completion for the CLI as a whole.
    #     Optional. If not provided, {Toys::CLI.default_completion} is called
    #     to get a default completion that delegates to the tool.
    #
    # @param middleware_stack [Array<Toys::Middleware::Spec>] An array of
    #     middleware that will be used by default for all tools.
    #     Optional. If not provided, uses a default set of middleware defined
    #     in {Toys::CLI.default_middleware_stack}. To include no middleware,
    #     pass the empty array explicitly.
    # @param mixin_lookup [Toys::ModuleLookup] A lookup for well-known mixin
    #     modules (i.e. with symbol names).
    #     Optional. If not provided, defaults to the set of standard mixins
    #     provided by toys-core, as defined by
    #     {Toys::CLI.default_mixin_lookup}. If you explicitly want no standard
    #     mixins, pass an empty instance of {Toys::ModuleLookup}.
    # @param middleware_lookup [Toys::ModuleLookup] A lookup for well-known
    #     middleware classes.
    #     Optional. If not provided, defaults to the set of standard middleware
    #     classes provided by toys-core, as defined by
    #     {Toys::CLI.default_middleware_lookup}. If you explicitly want no
    #     standard middleware, pass an empty instance of
    #     {Toys::ModuleLookup}.
    # @param template_lookup [Toys::ModuleLookup] A lookup for well-known
    #     template classes.
    #     Optional. If not provided, defaults to the set of standard template
    #     classes provided by toys core, as defined by
    #     {Toys::CLI.default_template_lookup}. If you explicitly want no
    #     standard templates, pass an empty instance of {Toys::ModuleLookup}.
    #
    # @param config_dir_name [String] A directory with this name that appears
    #     in the loader path, is treated as a configuration directory whose
    #     contents are loaded into the toys configuration.
    #     Optional. If not provided, toplevel configuration directories are
    #     disabled.
    #     Note: the standard toys executable sets this to `".toys"`.
    # @param config_file_name [String] A file with this name that appears in
    #     the loader path, is treated as a toplevel configuration file whose
    #     contents are loaded into the toys configuration. This does not
    #     include "index" configuration files located within a configuration
    #     directory.
    #     Optional. If not provided, toplevel configuration files are disabled.
    #     Note: the standard toys executable sets this to `".toys.rb"`.
    # @param index_file_name [String] A file with this name that appears in any
    #     configuration directory is loaded first as a standalone configuration
    #     file. This does not include "toplevel" configuration files outside
    #     configuration directories.
    #     Optional. If not provided, index configuration files are disabled.
    #     Note: the standard toys executable sets this to `".toys.rb"`.
    # @param preload_file_name [String] A file with this name that appears
    #     in any configuration directory is preloaded using `require` before
    #     any tools in that configuration directory are defined. A preload file
    #     includes normal Ruby code, rather than Toys DSL definitions. The
    #     preload file is loaded before any files in a preload directory.
    #     Optional. If not provided, preload files are disabled.
    #     Note: the standard toys executable sets this to `".preload.rb"`.
    # @param preload_dir_name [String] A directory with this name that appears
    #     in any configuration directory is searched for Ruby files, which are
    #     preloaded using `require` before any tools in that configuration
    #     directory are defined. Files in a preload directory include normal
    #     Ruby code, rather than Toys DSL definitions. Files in a preload
    #     directory are loaded after any standalone preload file.
    #     Optional. If not provided, preload directories are disabled.
    #     Note: the standard toys executable sets this to `".preload"`.
    # @param data_dir_name [String] A directory with this name that appears in
    #     any configuration directory is added to the data directory search
    #     path for any tool file in that directory.
    #     Optional. If not provided, data directories are disabled.
    #     Note: the standard toys executable sets this to `".data"`.
    # @param lib_dir_name [String] A directory with this name that appears in
    #     any configuration directory is added to the Ruby load path when
    #     executing any tool file in that directory.
    #     Optional. If not provided, lib directories are disabled.
    #     Note: the standard toys executable sets this to `".lib"`.
    #
    def initialize(executable_name: nil, # rubocop:disable Metrics/MethodLength
                   middleware_stack: nil,
                   extra_delimiters: "",
                   config_dir_name: nil,
                   config_file_name: nil,
                   index_file_name: nil,
                   preload_file_name: nil,
                   preload_dir_name: nil,
                   data_dir_name: nil,
                   lib_dir_name: nil,
                   mixin_lookup: nil,
                   middleware_lookup: nil,
                   template_lookup: nil,
                   logger_factory: nil,
                   logger: nil,
                   base_level: nil,
                   error_handler: nil,
                   completion: nil)
      @executable_name = executable_name || ::File.basename($PROGRAM_NAME)
      @middleware_stack = middleware_stack || CLI.default_middleware_stack
      @mixin_lookup = mixin_lookup || CLI.default_mixin_lookup
      @middleware_lookup = middleware_lookup || CLI.default_middleware_lookup
      @template_lookup = template_lookup || CLI.default_template_lookup
      @error_handler = error_handler || CLI.default_error_handler
      @completion = completion || CLI.default_completion
      @logger = logger
      @param_logger_factory = logger_factory
      @logger_factory = logger ? proc { |_tool| logger } : logger_factory || CLI.default_logger_factory
      @base_level = base_level
      @extra_delimiters = extra_delimiters
      @tool_name_splitter = ToolNameSplitter.new(extra_delimiters)
      @config_dir_name = config_dir_name
      @config_file_name = config_file_name
      @index_file_name = index_file_name
      @preload_file_name = preload_file_name
      @preload_dir_name = preload_dir_name
      @data_dir_name = data_dir_name
      @lib_dir_name = lib_dir_name
      @loader = Loader.new(
        index_file_name: @index_file_name,
        preload_dir_name: @preload_dir_name,
        preload_file_name: @preload_file_name,
        data_dir_name: @data_dir_name,
        lib_dir_name: @lib_dir_name,
        middleware_stack: @middleware_stack,
        tool_name_splitter: @tool_name_splitter,
        mixin_lookup: @mixin_lookup,
        template_lookup: @template_lookup,
        middleware_lookup: @middleware_lookup
      )
      @runner = Runner.new(@loader,
                           logger_factory: @logger_factory,
                           base_level: @base_level,
                           error_handler: @error_handler,
                           executable_name: @executable_name,
                           external_data: {Context::Key::CLI => self})
    end

    ##
    # Make a clone with the same settings. By default, the new CLI has no
    # config blocks and no paths in its loader, which is sometimes useful for
    # calling another tool that has to be loaded from a different
    # configuration. Alternately, you can pass `copy_loader_sources: true` to
    # start with the same sources as the original. This is useful if you need
    # to run a tool with an additional source, because sources cannot be added
    # to a loader once it has started loading tools.
    #
    # Sources are copied before the block (if any) is called, so any sources
    # the block adds at high priority will take priority over the copies.
    #
    # @param copy_loader_sources [boolean] If true, the new CLI's loader is
    #     populated with the same sources as the original CLI's loader. The
    #     sources are not reresolved; in particular, gems are not reactivated
    #     and git repos are not refetched. Defaults to false.
    #
    #     Note that the `data_dir_name` and `lib_dir_name` settings are
    #     captured by each source when it is added, so a copied source retains
    #     the values from the original CLI. Rather than apply such a change
    #     inconsistently, this method raises if you try to modify either
    #     setting while also copying sources. This is a current limitation and
    #     may be lifted in the future.
    # @param opts [keywords] Any configuration arguments that should be
    #     modified from the original. See {#initialize} for a list of
    #     recognized keywords.
    # @return [Toys::CLI]
    # @raise [ArgumentError] if `copy_loader_sources` is true and either
    #     `data_dir_name` or `lib_dir_name` is modified.
    # @yieldparam cli [Toys::CLI] If you pass a block, the new CLI is yielded
    #     to it so you can add paths and make other modifications.
    #
    def child(copy_loader_sources: false, **opts)
      if copy_loader_sources
        check_source_copy_conflict(opts, :data_dir_name, @data_dir_name)
        check_source_copy_conflict(opts, :lib_dir_name, @lib_dir_name)
      end
      cli = CLI.new(**current_settings, **opts)
      cli.loader.add_source_root_records(@loader.source_root_records) if copy_loader_sources
      yield cli if block_given?
      cli
    end

    ##
    # The current loader for this CLI.
    # @return [Toys::Loader]
    #
    attr_reader :loader

    ##
    # The runner this CLI uses to run tools, configured with this CLI's
    # settings. Use it directly when you need more control over a single run
    # than {#run} provides, such as turning off error handling. Note that
    # {#child} builds a new CLI with a runner of its own.
    # @return [Toys::Runner]
    #
    attr_reader :runner

    ##
    # The effective executable name used for usage text in this CLI.
    # @return [String]
    #
    attr_reader :executable_name

    ##
    # The string of tool name delimiter characters (besides space).
    # @return [String]
    #
    attr_reader :extra_delimiters

    ##
    # The splitter that interprets delimiters in tool names, reflecting this
    # CLI's {#extra_delimiters}.
    # @return [Toys::ToolNameSplitter]
    #
    attr_reader :tool_name_splitter

    ##
    # The global logger, if any.
    # @return [Logger,nil]
    #
    attr_reader :logger

    ##
    # The logger factory.
    # @return [Proc]
    #
    attr_reader :logger_factory

    ##
    # The initial logger level in this CLI, used as the level for verbosity 0.
    # May be `nil`, indicating it will use the initial logger setting.
    # @return [Integer,nil]
    #
    attr_reader :base_level

    ##
    # The overall completion strategy for this CLI.
    # @return [Toys::Completion::Base,Proc]
    #
    attr_reader :completion

    ##
    # Add a specific configuration file or directory to the loader.
    #
    # This is generally used to load a static or "built-in" set of tools,
    # either for a standalone command line executable based on Toys, or to
    # provide a "default" set of tools for a dynamic executable. For example,
    # the main Toys executable uses this to load the builtin tools from its
    # "builtins" directory.
    #
    # @param path [String] A path to add. May reference a single Toys file or
    #     a Toys directory.
    # @param high_priority [boolean] Add the config at the head of the priority
    #     list rather than the tail.
    # @param source_name [String] A custom name for the root source. Optional.
    # @param context_directory [String,nil,:path,:parent] The context directory
    #     for tools loaded from this path. You can pass a directory path as a
    #     string, `:path` to denote the given path, `:parent` to denote the
    #     given path's parent directory, or `nil` to denote no context.
    #     Defaults to `:parent`.
    # @return [self]
    #
    def add_config_path(path,
                        high_priority: false,
                        source_name: nil,
                        context_directory: :parent)
      @loader.add_path(path,
                       high_priority: high_priority,
                       source_name: source_name,
                       context_directory: context_directory)
      self
    end

    ##
    # Add a configuration block to the loader.
    #
    # This is used to create tools "inline", and is useful for simple command
    # line executables based on Toys.
    #
    # @param high_priority [boolean] Add the config at the head of the priority
    #     list rather than the tail.
    # @param source_name [String] The source name that will be shown in
    #     documentation for tools defined in this block. If omitted, a default
    #     unique string will be generated.
    # @param block [Proc] The block of configuration, executed in the context
    #     of the tool DSL {Toys::DSL::Tool}.
    # @param context_directory [String,nil] The context directory for tools
    #     loaded from this block. You can pass a directory path as a string, or
    #     `nil` to denote no context. Defaults to `nil`.
    # @return [self]
    #
    def add_config_block(high_priority: false,
                         source_name: nil,
                         context_directory: nil,
                         &block)
      @loader.add_block(high_priority: high_priority,
                        source_name: source_name,
                        context_directory: context_directory,
                        &block)
      self
    end

    ##
    # Add the tools from a gem to the loader.
    #
    # The gem is activated, installing it if necessary, and tools are loaded
    # from the gem's toys directory (or a file or subdirectory within it).
    #
    # @param gem_name [String] The name of the gem.
    # @param gem_version [String,Array<String>] Version requirements for the
    #     gem. Optional. If not provided, any version is allowed.
    # @param gem_path [String,nil] The path from the gem's toys directory to
    #     the relevant file or directory. Optional. If not provided, the entire
    #     toys directory is used.
    # @param high_priority [boolean] Add the config at the head of the priority
    #     list rather than the tail.
    # @param source_name [String] A custom name for the root source. Optional.
    # @param gem_toys_dir [String] The name of the gem's toys directory.
    #     Optional. Defaults to the directory specified in the gem's metadata,
    #     or the value "toys".
    # @param context_directory [String,nil] The context directory for tools
    #     loaded from this source. You can pass a directory path as a string,
    #     or `nil` to denote no context. Defaults to `nil`.
    # @return [self]
    #
    def add_config_gem(gem_name,
                       gem_version: [],
                       gem_path: nil,
                       high_priority: false,
                       source_name: nil,
                       gem_toys_dir: nil,
                       context_directory: nil)
      @loader.add_gem(gem_name, gem_version, gem_path,
                      high_priority: high_priority,
                      source_name: source_name,
                      gem_toys_dir: gem_toys_dir,
                      context_directory: context_directory)
      self
    end

    ##
    # Add the tools from a git repository to the loader.
    #
    # The repository is fetched into a local cache, and tools are loaded from
    # it (or from a file or subdirectory within it).
    #
    # @param git_remote [String] The git repo URL.
    # @param git_path [String] The path to the relevant file or directory in
    #     the repo. Optional. Defaults to the entire repo.
    # @param git_commit [String] The git ref (i.e. SHA, tag, or branch name).
    #     Optional. Defaults to `"HEAD"`.
    # @param high_priority [boolean] Add the config at the head of the priority
    #     list rather than the tail.
    # @param source_name [String] A custom name for the root source. Optional.
    # @param update [boolean] If the commit is not a SHA, pulls any updates
    #     from the remote. Defaults to false, which uses a local cache and does
    #     not update if the commit has been fetched previously.
    # @param context_directory [String,nil] The context directory for tools
    #     loaded from this source. You can pass a directory path as a string,
    #     or `nil` to denote no context. Defaults to `nil`.
    # @return [self]
    #
    def add_config_git(git_remote,
                       git_path: "",
                       git_commit: "HEAD",
                       high_priority: false,
                       source_name: nil,
                       update: false,
                       context_directory: nil)
      @loader.add_git(git_remote, git_path, git_commit,
                      high_priority: high_priority,
                      source_name: source_name,
                      update: update,
                      context_directory: context_directory)
      self
    end

    ##
    # Checks the given directory path. If it contains a config file and/or
    # config directory, those are added to the loader.
    #
    # The main Toys executable uses this method to load tools from directories
    # in the `TOYS_PATH`.
    #
    # @param search_path [String] A path to search for configs.
    # @param high_priority [boolean] Add the configs at the head of the
    #     priority list rather than the tail.
    # @param context_directory [String,nil,:path,:parent] The context directory
    #     for tools loaded from this path. You can pass a directory path as a
    #     string, `:path` to denote the given path, `:parent` to denote the
    #     given path's parent directory, or `nil` to denote no context.
    #     Defaults to `:path`.
    # @return [self]
    #
    def add_search_path(search_path,
                        high_priority: false,
                        context_directory: :path)
      paths = []
      if @config_file_name
        file_path = ::File.join(search_path, @config_file_name)
        paths << @config_file_name if !::File.directory?(file_path) && ::File.readable?(file_path)
      end
      if @config_dir_name
        dir_path = ::File.join(search_path, @config_dir_name)
        paths << @config_dir_name if ::File.directory?(dir_path) && ::File.readable?(dir_path)
      end
      @loader.add_path_set(search_path, paths,
                           high_priority: high_priority,
                           context_directory: context_directory)
      self
    end

    ##
    # Walk up the directory hierarchy from the given start location, and add to
    # the loader any config files and directories found.
    #
    # The main Toys executable uses this method to load tools from the current
    # directory and its ancestors.
    #
    # @param start [String] The first directory to add. Defaults to the current
    #     working directory.
    # @param terminate [Array<String>] Optional list of directories that should
    #     terminate the search. If the walk up the directory tree encounters
    #     one of these directories, the search is halted without checking the
    #     terminating directory.
    # @param high_priority [boolean] Add the configs at the head of the
    #     priority list rather than the tail.
    # @return [self]
    #
    def add_search_path_hierarchy(start: nil, terminate: [], high_priority: false)
      path = start || ::Dir.pwd
      paths = []
      loop do
        break if terminate.include?(path)
        paths << path
        next_path = ::File.dirname(path)
        break if next_path == path
        path = next_path
      end
      paths.reverse! if high_priority
      paths.each do |p|
        add_search_path(p, high_priority: high_priority)
      end
      self
    end

    ##
    # Run the CLI with the given command line arguments.
    # Handles exceptions using the error handler.
    #
    # Any error that is not handled by the tool itself is passed to this CLI's
    # error handler, and this method returns the exit code that the handler
    # produces. Ordinary errors arrive as a {Toys::ContextualError} wrapper,
    # but a signal that no tool intercepted arrives as the `SignalException`
    # itself, unwrapped. See the `error_handler` argument to {#initialize}.
    #
    # @param args [String...] Command line arguments specifying which tool to
    #     run and what arguments to pass to it. You may pass either a single
    #     array of strings, or a series of string arguments.
    # @param verbosity [Integer] Initial verbosity. Default is 0.
    #
    # @return [Integer] The resulting process status code (i.e. 0 for success).
    #
    def run(*args, verbosity: 0)
      @runner.run(args.flatten, verbosity: verbosity)
    end

    ##
    # Prepare a tool to be run, but just execute the given block rather than
    # performing a full run of the tool. This is intended for testing tools.
    #
    # Unlike {#run}, this neither wraps errors nor passes them to the error
    # handler. An error such as a failure to parse arguments or to load the
    # requested tool is raised out of this method as-is, so the block does not
    # execute and this method does not return.
    #
    # @param args [String...] Command line arguments specifying which tool to
    #     run and what arguments to pass to it. You may pass either a single
    #     array of strings, or a series of string arguments.
    # @param verbosity [Integer] Initial verbosity. Default is 0.
    # @yieldparam context [Toys::Context] Yields the tool context.
    #
    # @return [Object] The value returned from the block.
    #
    def load_tool(*args, verbosity: 0)
      result = nil
      @runner.run(args.flatten, verbosity: verbosity,
                  wrap_errors: false, handle_errors: false) do |ctx|
        result = yield ctx
      end
      result
    end

    class << self
      ##
      # Returns a default set of middleware that may be used as a starting
      # point for a typical CLI. This set includes the following in order:
      #
      # *  {Toys::StandardMiddleware::SetDefaultDescriptions} providing
      #    defaults for description fields.
      # *  {Toys::StandardMiddleware::ShowHelp} adding the `--help` flag and
      #    providing default behavior for namespaces.
      # *  {Toys::StandardMiddleware::HandleUsageErrors}
      # *  {Toys::StandardMiddleware::AddVerbosityFlags} adding the `--verbose`
      #    and `--quiet` flags for managing the logger level.
      #
      # @return [Array<Toys::Middleware::Spec>]
      #
      def default_middleware_stack
        [
          Middleware.spec(:set_default_descriptions),
          Middleware.spec(:show_help, help_flags: true, fallback_execution: true),
          Middleware.spec(:handle_usage_errors),
          Middleware.spec(:add_verbosity_flags),
        ]
      end

      ##
      # Returns a default ModuleLookup for mixins that points at the
      # StandardMixins module.
      #
      # @return [Toys::ModuleLookup]
      #
      def default_mixin_lookup
        ModuleLookup.new.add_path("toys/standard_mixins")
      end

      ##
      # Returns a default ModuleLookup for middleware that points at the
      # StandardMiddleware module.
      #
      # @return [Toys::ModuleLookup]
      #
      def default_middleware_lookup
        ModuleLookup.new.add_path("toys/standard_middleware")
      end

      ##
      # Returns a default empty ModuleLookup for templates.
      #
      # @return [Toys::ModuleLookup]
      #
      def default_template_lookup
        ModuleLookup.new
      end

      ##
      # Returns a bare-bones error handler that simply reraises the error it is
      # given. A {Toys::ContextualError} is reraised as itself, so that a
      # rescue block has access to the context information. An unhandled
      # `SignalException` (or a subclass such as `Interrupt`) is also reraised
      # as itself, so that the Ruby VM has a chance to handle it normally.
      #
      # @return [Proc]
      #
      def default_error_handler
        Runner::DEFAULT_ERROR_HANDLER
      end

      ##
      # Returns a default logger factory that generates simple loggers that
      # write to the current stderr.
      #
      # @return [Proc]
      #
      def default_logger_factory
        Runner::DEFAULT_LOGGER_FACTORY
      end

      ##
      # Returns a default Completion that simply uses the tool's completion.
      #
      def default_completion
        proc do |context|
          context.tool.completion.call(context)
        end
      end
    end

    private

    ##
    # The configuration settings of this CLI, as a hash of constructor
    # arguments suitable for creating a copy.
    #
    def current_settings
      {
        executable_name: @executable_name,
        config_dir_name: @config_dir_name,
        config_file_name: @config_file_name,
        index_file_name: @index_file_name,
        preload_dir_name: @preload_dir_name,
        preload_file_name: @preload_file_name,
        data_dir_name: @data_dir_name,
        lib_dir_name: @lib_dir_name,
        middleware_stack: @middleware_stack,
        extra_delimiters: @extra_delimiters,
        mixin_lookup: @mixin_lookup,
        middleware_lookup: @middleware_lookup,
        template_lookup: @template_lookup,
        logger: @logger,
        logger_factory: @param_logger_factory,
        base_level: @base_level,
        error_handler: @error_handler,
        completion: @completion,
      }
    end

    ##
    # Raise if the given options would modify a setting that is captured by the
    # sources being copied, and thus could not be applied to them.
    #
    def check_source_copy_conflict(opts, key, current_value)
      return unless opts.key?(key) && opts[key] != current_value
      raise ::ArgumentError,
            "Cannot change #{key} while copying loader sources, because the setting is" \
            " captured in the copied sources."
    end
  end
end
