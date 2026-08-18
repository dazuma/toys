# frozen_string_literal: true

require "logger"
require "monitor"

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
  #     cli.add_source_block do
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
    #  *  Options affecting tool sources
    #      *  `toplevel_tool_dir_name`: Directory name containing tool files
    #      *  `toplevel_tool_file_name`: File name for tools
    #      *  `git_cache`: Custom GitCache to use for git sources
    #      *  `gems_util`: Custom Gems utility to use for gem sources
    #      *  `sources`: Initial sources to populate
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
    # @param toplevel_tool_dir_name [String] Tools are loaded from directories
    #     of this name that appear in a search path.
    #     Optional. If not provided, search paths do not load tool directories.
    #     The standard toys executable sets this to `".toys"`.
    # @param toplevel_tool_file_name [String] Tools are loaded from files of
    #     this name that appear in a search path.
    #     Optional. If not provided, search paths do not load tool files.
    #     The standard toys executable sets this to `".toys.rb"`.
    #     Note: This setting does not affect the name of "index" toys files,
    #     which is fixed at `".toys.rb"`.
    # @param git_cache [Toys::Utils::GitCache] A custom GitCache instance to
    #     use to resolve git sources. Optional.
    # @param gems_util [Toys::Utils::Gems] A custom Gems utility instance to
    #     use to resolve gem sources. Optional.
    # @param sources [Array<Toys::SourceInfo>] An optional list of sources to
    #     populate into the source list. Most callers, however, should make
    #     calls to the `add_*` methods instead.
    #
    def initialize(executable_name: nil,
                   middleware_stack: nil,
                   extra_delimiters: "",
                   toplevel_tool_dir_name: nil,
                   toplevel_tool_file_name: nil,
                   mixin_lookup: nil,
                   middleware_lookup: nil,
                   template_lookup: nil,
                   logger_factory: nil,
                   logger: nil,
                   base_level: nil,
                   error_handler: nil,
                   completion: nil,
                   git_cache: nil,
                   gems_util: nil,
                   sources: nil)
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
      @toplevel_tool_dir_name = toplevel_tool_dir_name
      @toplevel_tool_file_name = toplevel_tool_file_name
      @git_cache = git_cache
      @gems_util = gems_util
      @source_list_builder = SourceListBuilder.new(git_cache: git_cache, gems_util: gems_util, sources: sources)
      @loader = @runner = nil
      @source_definition_mutex = ::Monitor.new
    end

    ##
    # Make a clone of this CLI with the same settings.
    #
    # By default, the new CLI has no tool sources, which is sometimes useful
    # for calling another tool that has to be loaded from a different source
    # configuration. Alternately, you can pass `copy_sources: true` to start
    # with the same sources as the original (to which you can add additional
    # sources before starting to load tools). Sources are copied before the
    # block (if any) is called, so any sources the block adds at high priority
    # will take priority over the originals.
    #
    # @param copy_sources [boolean] If true, the new CLI is populated with the
    #     same sources as the original.
    # @param opts [keywords] Any configuration arguments that should be
    #     modified from the original. See {#initialize} for a list of
    #     recognized keywords.
    # @return [Toys::CLI]
    # @yieldparam cli [Toys::CLI] If you pass a block, the new CLI is yielded
    #     to it so you can add paths and make other modifications.
    #
    def child(copy_sources: false, **opts)
      cli = CLI.new(**current_settings(copy_sources), **opts)
      yield cli if block_given?
      cli
    end

    ##
    # The current loader for this CLI.
    #
    # Note that calling this finalizes this CLI's source list if not already
    # finalized. Any subsequent attempt to add a source raises
    # {Toys::SourceListFinalizedError}.
    #
    # @return [Toys::Loader]
    #
    def loader
      finalize_sources!
      @loader
    end

    ##
    # The runner this CLI uses to run tools, configured with this CLI's
    # settings. Use it directly when you need more control over a single run
    # than {#run} provides, such as turning off error handling.
    #
    # Note that calling this finalizes this CLI's source list if not already
    # finalized. Any subsequent attempt to add a source raises
    # {Toys::SourceListFinalizedError}.
    #
    # @return [Toys::Runner]
    #
    def runner
      finalize_sources!
      @runner
    end

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
    # Add a specific tool file or directory to the source list.
    #
    # This is generally used to load a static or "built-in" set of tools,
    # either for a standalone command line executable based on Toys, or to
    # provide a "default" set of tools for a dynamic executable. For example,
    # the main Toys executable uses this to load the builtin tools from its
    # "builtins" directory.
    #
    # @param path [String] A path to add. May reference a single tool file or a
    #     tool directory.
    # @param high_priority [boolean] Add the source at the head of the priority
    #     list rather than the tail.
    # @param source_name [String] A custom name for the root source. Optional.
    # @param context_directory [String,nil,:path,:parent] The context directory
    #     for tools loaded from this path. You can pass a directory path as a
    #     string, `:path` to denote the given path, `:parent` to denote the
    #     given path's parent directory, or `nil` to denote no context.
    #     Defaults to `:parent`.
    #
    # @return [self]
    # @raise [Toys::SourceListFinalizedError] if the source list has already
    #     been finalized.
    # @raise [Toys::ToolDefinitionError] if the given path does not point at
    #     a readable Ruby file or directory.
    #
    def add_source_path(path,
                        high_priority: false,
                        source_name: nil,
                        context_directory: :parent)
      ensure_open_source_list do
        @source_list_builder.add_path(path,
                                      high_priority: high_priority,
                                      source_name: source_name,
                                      context_directory: context_directory)
      end
      self
    end
    alias add_config_path add_source_path

    ##
    # Add a block to the source list.
    #
    # This is used to create tools "inline", and is useful for simple command
    # line executables based on Toys.
    #
    # @param high_priority [boolean] Add the source at the head of the priority
    #     list rather than the tail.
    # @param source_name [String] The source name that will be shown in
    #     documentation for tools defined in this block. If omitted, a default
    #     unique string will be generated.
    # @param block [Proc] The source block, executed in the context of the tool
    #     DSL {Toys::DSL::Tool}.
    # @param context_directory [String,nil] The context directory for tools
    #     loaded from this block. You can pass a directory path as a string, or
    #     `nil` to denote no context. Defaults to `nil`.
    #
    # @return [self]
    # @raise [Toys::SourceListFinalizedError] if the source list has already
    #     been finalized.
    #
    def add_source_block(high_priority: false,
                         source_name: nil,
                         context_directory: nil,
                         &block)
      ensure_open_source_list do
        @source_list_builder.add_block(high_priority: high_priority,
                                       source_name: source_name,
                                       context_directory: context_directory,
                                       &block)
      end
      self
    end
    alias add_config_block add_source_block

    ##
    # Add the tools from a gem to the source list.
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
    # @param gem_toys_dir [String] The name of the gem's toys directory.
    #     Optional. Defaults to the directory specified in the gem's metadata,
    #     or the value "toys".
    # @param high_priority [boolean] Add the source at the head of the priority
    #     list rather than the tail.
    # @param source_name [String] A custom name for the root source. Optional.
    # @param context_directory [String,nil] The context directory for tools
    #     loaded from this source. You can pass a directory path as a string,
    #     or `nil` to denote no context. Defaults to `nil`.
    #
    # @return [self]
    # @raise [Toys::SourceListFinalizedError] if the source list has already
    #     been finalized.
    # @raise [Toys::ToolDefinitionError] if the specified gem could not be
    #     activated or did not contain valid toys files/directories.
    #
    def add_source_gem(gem_name,
                       gem_version: nil,
                       gem_path: nil,
                       gem_toys_dir: nil,
                       high_priority: false,
                       source_name: nil,
                       context_directory: nil)
      ensure_open_source_list do
        @source_list_builder.add_gem(gem_name,
                                     gem_version: gem_version,
                                     gem_path: gem_path,
                                     gem_toys_dir: gem_toys_dir,
                                     high_priority: high_priority,
                                     source_name: source_name,
                                     context_directory: context_directory)
      end
      self
    end
    alias add_config_gem add_source_gem

    ##
    # Add the tools from a git repository to the source list.
    #
    # The repository is fetched into a local cache, and tools are loaded from
    # it (or from a file or subdirectory within it).
    #
    # @param git_remote [String] The git repo URL.
    # @param git_path [String] The path to the relevant file or directory in
    #     the repo. Optional. Defaults to the entire repo.
    # @param git_commit [String] The git ref (i.e. SHA, tag, or branch name).
    #     Optional. Defaults to `"HEAD"`.
    # @param update [boolean,Integer] Whether to update non-SHA commit
    #     references if they were previously loaded. This is useful, for
    #     example, if the commit is `HEAD` or a branch name. Pass `true` or
    #     `false` to specify whether to update, or an integer to update if
    #     last update was done at least that many seconds ago. Default is
    #     `false`.
    # @param high_priority [boolean] Add the source at the head of the priority
    #     list rather than the tail.
    # @param source_name [String] A custom name for the root source. Optional.
    # @param context_directory [String,nil] The context directory for tools
    #     loaded from this source. You can pass a directory path as a string,
    #     or `nil` to denote no context. Defaults to `nil`.
    #
    # @return [self]
    # @raise [Toys::SourceListFinalizedError] if the source list has already
    #     been finalized.
    # @raise [Toys::ToolDefinitionError] if the specified git repo could not be
    #     accessed or did not contain valid toys files/directories.
    #
    def add_source_git(git_remote,
                       git_path: nil,
                       git_commit: nil,
                       update: false,
                       high_priority: false,
                       source_name: nil,
                       context_directory: nil)
      ensure_open_source_list do
        @source_list_builder.add_git(git_remote,
                                     git_path: git_path,
                                     git_commit: git_commit,
                                     high_priority: high_priority,
                                     source_name: source_name,
                                     update: update,
                                     context_directory: context_directory)
      end
      self
    end
    alias add_config_git add_source_git

    ##
    # Checks the given directory path. If it contains a tool file and/or
    # tool directory, those are added to the source list.
    #
    # The main Toys executable uses this method to load tools from directories
    # in the `TOYS_PATH`.
    #
    # @param search_path [String] A path to search for sources.
    # @param high_priority [boolean] Add the sources at the head of the
    #     priority list rather than the tail.
    # @param context_directory [String,nil,:path,:parent] The context directory
    #     for tools loaded from this path. You can pass a directory path as a
    #     string, `:path` to denote the given path, `:parent` to denote the
    #     given path's parent directory, or `nil` to denote no context.
    #     Defaults to `:path`.
    #
    # @return [self]
    # @raise [Toys::SourceListFinalizedError] if the source list has already
    #     been finalized.
    #
    def add_search_path(search_path,
                        high_priority: false,
                        context_directory: :path)
      ensure_open_source_list do
        paths = []
        if @toplevel_tool_file_name
          file_path = ::File.join(search_path, @toplevel_tool_file_name)
          paths << @toplevel_tool_file_name if !::File.directory?(file_path) && ::File.readable?(file_path)
        end
        if @toplevel_tool_dir_name
          dir_path = ::File.join(search_path, @toplevel_tool_dir_name)
          paths << @toplevel_tool_dir_name if ::File.directory?(dir_path) && ::File.readable?(dir_path)
        end
        @source_list_builder.add_path_set(search_path, paths,
                                          high_priority: high_priority,
                                          context_directory: context_directory)
      end
      self
    end

    ##
    # Walk up the directory hierarchy from the given start location, and add
    # any tool files and directories found.
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
    # @param high_priority [boolean] Add the sources at the head of the
    #     priority list rather than the tail.
    #
    # @return [self]
    # @raise [Toys::SourceListFinalizedError] if the source list has already
    #     been finalized.
    #
    def add_search_path_hierarchy(start: nil,
                                  terminate: [],
                                  high_priority: false)
      ensure_open_source_list do
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
    # Note that calling this finalizes this CLI's source list if not already
    # finalized. Any subsequent attempt to add a source raises
    # {Toys::SourceListFinalizedError}.
    #
    # @param args [String...] Command line arguments specifying which tool to
    #     run and what arguments to pass to it. You may pass either a single
    #     array of strings, or a series of string arguments.
    # @param verbosity [Integer] Initial verbosity. Default is 0.
    #
    # @return [Integer] The resulting process status code (i.e. 0 for success).
    #
    def run(*args, verbosity: 0)
      runner.run(args.flatten, verbosity: verbosity)
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
    # Note that calling this finalizes this CLI's source list if not already
    # finalized. Any subsequent attempt to add a source raises
    # {Toys::SourceListFinalizedError}.
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
      runner.run(args.flatten, verbosity: verbosity,
                 wrap_errors: false, handle_errors: false) do |ctx|
        result = yield ctx
      end
      result
    end

    ##
    # Finalize the source list. Any subsequent attempt to add a source will
    # raise {Toys::SourceListFinalizedError}.
    #
    # @return [self]
    #
    def finalize_sources!
      @source_definition_mutex.synchronize do
        unless @loader
          loader = Loader.new(@source_list_builder.sources,
                              git_cache: @git_cache,
                              gems_util: @gems_util,
                              middleware_stack: @middleware_stack,
                              tool_name_splitter: @tool_name_splitter,
                              mixin_lookup: @mixin_lookup,
                              template_lookup: @template_lookup,
                              middleware_lookup: @middleware_lookup)
          runner = Runner.new(loader,
                              logger_factory: @logger_factory,
                              base_level: @base_level,
                              error_handler: @error_handler,
                              executable_name: @executable_name,
                              external_data: {Context::Key::CLI => self})
          @loader = loader
          @runner = runner
        end
      end
      self
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
    # Synchronize access to the source list. Ensures that the source list is
    # still open for additions, and serializes the given block.
    #
    # @raise [Toys::SourceListFinalizedError] if the source list is finalized.
    #
    def ensure_open_source_list
      @source_definition_mutex.synchronize do
        if @loader
          raise SourceListFinalizedError,
                "Cannot add a source because this CLI's source list has already been finalized"
        end
        yield
      end
    end

    ##
    # The configuration settings of this CLI, as a hash of constructor
    # arguments suitable for creating a copy.
    #
    def current_settings(copy_sources)
      result = {
        executable_name: @executable_name,
        toplevel_tool_dir_name: @toplevel_tool_dir_name,
        toplevel_tool_file_name: @toplevel_tool_file_name,
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
        git_cache: @git_cache,
        gems_util: @gems_util,
      }
      result[:sources] = @source_definition_mutex.synchronize { @source_list_builder.sources } if copy_sources
      result
    end
  end
end
