# frozen_string_literal: true

module Toys
  ##
  # Subclass of `Toys::CLI` configured for the behavior of the standard Toys
  # executable. Specifically, this subclass:
  #
  # * Configures the standard names of files and directories, such as the
  #   `.toys.rb` file for an "index" tool, and the `.data` and `.lib` directory
  #   names.
  # * Configures default descriptions for the root tool.
  # * Configures a default error handler and logger that provide ANSI-colored
  #   formatted output.
  # * Configures a set of middleware that implement online help, verbosity
  #   flags, and other features.
  # * Provides a set of standard templates for typical project build and
  #   maintenance scripts (suh as clean, test, and rubocop).
  # * Finds tool definitions in the standard Toys search path.
  #
  class StandardCLI < CLI
    ##
    # Standard toys tool directory name.
    # @return [String]
    #
    TOPLEVEL_TOOL_DIR_NAME = ".toys"

    ##
    # Standard toys tool file name.
    # @return [String]
    #
    TOPLEVEL_TOOL_FILE_NAME = ".toys.rb"

    ##
    # Name of the standard toys executable.
    # @return [String]
    #
    EXECUTABLE_NAME = "toys"

    ##
    # Delimiter characters recognized.
    # @return [String]
    #
    EXTRA_DELIMITERS = ":."

    ##
    # Short description for the standard root tool.
    # @return [String]
    #
    DEFAULT_ROOT_DESC = "Your personal command line tool"

    ##
    # Help text for the standard root tool.
    # @return [String]
    #
    DEFAULT_ROOT_LONG_DESC =
      "Toys is your personal command line tool. You can write commands using a simple Ruby DSL," \
      " and Toys will automatically organize them, parse arguments, and provide documentation." \
      " Tools can be global or scoped to specific directories. You can also use Toys instead of" \
      " Rake to provide build and maintenance scripts for your projects." \
      " For detailed information, see https://dazuma.github.io/toys"

    ##
    # Short description for the version flag.
    # @return [String]
    #
    DEFAULT_VERSION_FLAG_DESC = "Show the version of Toys."

    ##
    # Name of the environment variable that selects which groups of global
    # sources are searched.
    # @return [String]
    #
    GLOBAL_SOURCES_ENV = "TOYS_GLOBAL_SOURCES"

    ##
    # The groups of global sources, in search order. The `home` group is
    # `$HOME/.toys.rb` and `$HOME/.toys/`, the `user` group is the `toys`
    # tool directory under `$XDG_CONFIG_HOME`, and the `site` group is the
    # `toys` tool directories under each of `$XDG_CONFIG_DIRS`.
    # @return [Array<String>]
    #
    GLOBAL_SOURCE_GROUPS = ["home", "user", "site"].freeze

    ##
    # Raised by the constructor if the `TOYS_GLOBAL_SOURCES` environment
    # variable has an invalid value.
    #
    class InvalidGlobalSourcesError < ::StandardError
    end

    ##
    # Create a standard CLI, configured with the appropriate paths and
    # middleware.
    #
    # @param custom_paths [String,Array<String>] Custom paths to use. If set,
    #     the CLI uses only the given paths. If not, the CLI will search for
    #     paths from the current directory and global paths, as selected by
    #     the `TOYS_GLOBAL_SOURCES` environment variable.
    # @param include_builtins [boolean] Add the builtin tools. Default is true.
    # @param cur_dir [String,nil] Starting search directory for sources.
    #     Defaults to the current working directory.
    # @param git_cache [Toys::Utils::GitCache,nil] A custom GitCache instance
    #     to use when resolving git sources. Optional. If nil or not
    #     specified, uses a process-wide default GitCache.
    # @param gems_util [Toys::Utils::Gems,nil] A custom Gems utility instance
    #     to use when resolving gem sources. Optional. If nil or not
    #     specified, uses a process-wide default Gems utility.
    # @raise [InvalidGlobalSourcesError] if no custom paths are given and the
    #     `TOYS_GLOBAL_SOURCES` environment variable has an invalid value.
    #
    def initialize(custom_paths: nil,
                   include_builtins: true,
                   cur_dir: nil,
                   git_cache: nil,
                   gems_util: nil)
      require "toys/utils/standard_ui"
      ui = Utils::StandardUI.new(
        backtrace_omit_prefixes: ::ENV["TOYS_TRACE"].to_s.empty? ? ::Toys.framework_lib_paths : nil,
        incomplete_backtrace_message: "(Set the TOYS_TRACE envvar to a nonempty value to see the full trace.)"
      )
      super(
        executable_name: EXECUTABLE_NAME,
        toplevel_tool_dir_name: TOPLEVEL_TOOL_DIR_NAME,
        toplevel_tool_file_name: TOPLEVEL_TOOL_FILE_NAME,
        extra_delimiters: EXTRA_DELIMITERS,
        middleware_stack: default_middleware_stack,
        template_lookup: default_template_lookup,
        git_cache: git_cache,
        gems_util: gems_util,
        **ui.cli_args
      )
      if custom_paths
        Array(custom_paths).each { |path| add_source(path) }
      else
        add_default_sources(cur_dir)
      end
      add_builtins if include_builtins
    end

    private

    ##
    # Add paths for builtin tools
    #
    def add_builtins
      builtins_path = ::File.join(::File.dirname(::File.dirname(__dir__)), "builtins")
      source_spec = SourceSpec.path(builtins_path, source_name: "(builtin tools)")
      add_source(source_spec)
      self
    end

    ##
    # Add the sources found by the default search: the current directory and
    # its ancestors, followed by the selected global sources.
    #
    # @param cur_dir [String,nil] The starting directory path, or nil to use
    #     the current directory
    # @return [self]
    #
    def add_default_sources(cur_dir)
      groups = selected_global_groups
      warn_removed_global_paths
      require "toys/utils/xdg"
      xdg = Utils::XDG.new
      home_dir = real_directory(xdg.home_dir)
      user_dirs = [real_directory(::File.join(xdg.config_home, "toys"))].compact
      site_dirs = xdg.config_dirs.map { |dir| real_directory(::File.join(dir, "toys")) }.compact
      walk_dirs = upward_walk_dirs(cur_dir || ::Dir.pwd, home_dir, user_dirs + site_dirs)
      walk_dirs.each { |dir| add_search_path(dir) }
      warn_etc_toys_files(walk_dirs)
      add_global_sources(groups, home_dir, user_dirs, site_dirs)
      self
    end

    ##
    # Parse and validate the global sources environment variable.
    #
    # @return [Array<String>] The selected groups
    # @raise [InvalidGlobalSourcesError] if the value is invalid
    #
    def selected_global_groups
      value = ::ENV[GLOBAL_SOURCES_ENV].to_s
      return GLOBAL_SOURCE_GROUPS if value.empty?
      return [] if value == "none"
      groups = value.split(",", -1)
      return groups if GLOBAL_SOURCE_GROUPS.select { |group| groups.include?(group) } == groups
      raise InvalidGlobalSourcesError,
            "Invalid value for #{GLOBAL_SOURCES_ENV}: #{value.inspect}. Expected \"none\", or a" \
            " comma-delimited list of groups from #{GLOBAL_SOURCE_GROUPS.join(',')} in that order."
    end

    ##
    # Add the global sources in the selected groups, skipping any directory
    # that resolves to one already added.
    #
    # @param groups [Array<String>] The selected groups
    # @param home_dir [String,nil] The real path of the home directory
    # @param user_dirs [Array<String>] Real paths of the user tool directories
    # @param site_dirs [Array<String>] Real paths of the site tool directories
    #
    def add_global_sources(groups, home_dir, user_dirs, site_dirs)
      added_dirs = []
      if groups.include?("home") && home_dir
        add_search_path(home_dir)
        home_toys_dir = real_directory(::File.join(home_dir, TOPLEVEL_TOOL_DIR_NAME))
        added_dirs << home_toys_dir if home_toys_dir
      end
      tool_dirs = []
      tool_dirs.concat(user_dirs) if groups.include?("user")
      tool_dirs.concat(site_dirs) if groups.include?("site")
      tool_dirs.each do |dir|
        next if added_dirs.include?(dir) || !::File.readable?(dir)
        added_dirs << dir
        add_source(SourceSpec.path(dir))
      end
    end

    ##
    # Returns the directories searched by the upward walk from the given
    # directory, or none if the directory is inside a global tool directory.
    #
    # @param cur_dir [String] The starting directory
    # @param home_dir [String,nil] The real path of the home directory
    # @param global_tool_dirs [Array<String>] Real paths of the global tool
    #     directories
    # @return [Array<String>]
    #
    def upward_walk_dirs(cur_dir, home_dir, global_tool_dirs)
      cur_dir = real_directory(cur_dir) || ::File.expand_path(cur_dir)
      cur_dir = skip_toys_dir(cur_dir, TOPLEVEL_TOOL_DIR_NAME)
      return [] if global_tool_dirs.any? { |dir| path_within?(cur_dir, dir) }
      walk_up(cur_dir, home_dir)
    end

    ##
    # Returns the directories visited by the upward walk, starting at the
    # given directory and stopping before the given terminating directory or
    # after the root.
    #
    # @param start [String] The starting directory
    # @param terminate [String,nil] The directory to stop before
    # @return [Array<String>]
    #
    def walk_up(start, terminate)
      dirs = []
      dir = start
      loop do
        break if dir == terminate
        dirs << dir
        parent = ::File.dirname(dir)
        break if parent == dir
        dir = parent
      end
      dirs
    end

    ##
    # Determines whether the given path is the given directory or is inside
    # it, comparing whole path components.
    #
    # @param path [String] The path to check
    # @param dir [String] The directory
    # @return [boolean]
    #
    def path_within?(path, dir)
      loop do
        return true if path == dir
        parent = ::File.dirname(path)
        return false if parent == path
        path = parent
      end
    end

    ##
    # Returns the real path of the given directory, or nil if it does not
    # exist or is not a directory.
    #
    # @param path [String] The directory path
    # @return [String,nil]
    #
    def real_directory(path)
      return nil unless ::File.directory?(path)
      ::File.realpath(path)
    rescue ::SystemCallError
      nil
    end

    ##
    # Warns if the removed `TOYS_PATH` environment variable is set.
    #
    def warn_removed_global_paths
      return if ::ENV["TOYS_PATH"].to_s.empty?
      Warnings.warn(:toys_path_removed,
                    "TOYS_PATH is no longer supported and is ignored. To relocate global tool" \
                    " directories, set XDG_CONFIG_HOME or XDG_CONFIG_DIRS. To suppress them, set" \
                    " #{GLOBAL_SOURCES_ENV}. To load tools from a path once, use `toys do --path`.",
                    max_count: 1)
    end

    ##
    # Warns if the removed `/etc` toys file or directory exists and was not
    # loaded by the upward walk.
    #
    # @param walk_dirs [Array<String>] The directories visited by the walk
    #
    def warn_etc_toys_files(walk_dirs)
      etc_dir = real_directory("/etc")
      return if etc_dir.nil? || walk_dirs.include?(etc_dir)
      file_path = ::File.join(etc_dir, TOPLEVEL_TOOL_FILE_NAME)
      dir_path = ::File.join(etc_dir, TOPLEVEL_TOOL_DIR_NAME)
      return unless ::File.exist?(file_path) || ::File.exist?(dir_path)
      Warnings.warn(:etc_toys_removed,
                    "/etc/#{TOPLEVEL_TOOL_FILE_NAME} and /etc/#{TOPLEVEL_TOOL_DIR_NAME} are no longer" \
                    " loaded. Move global tools into the /etc/xdg/toys directory instead.",
                    max_count: 1)
    end

    ##
    # Step out of any toys dir.
    #
    # @param dir [String] The starting path
    # @param toys_dir_name [String] The name of the toys directory to look for
    # @return [String] The final directory path
    #
    def skip_toys_dir(dir, toys_dir_name)
      cur_dir = dir
      loop do
        parent = ::File.dirname(dir)
        return cur_dir if parent == dir
        if ::File.basename(dir) == toys_dir_name
          cur_dir = dir = parent
        else
          dir = parent
        end
      end
    end

    ##
    # Returns the middleware for the standard Toys CLI.
    #
    # @return [Array]
    #
    def default_middleware_stack
      [
        Middleware.spec(:set_default_descriptions,
                        default_root_desc: DEFAULT_ROOT_DESC,
                        default_root_long_desc: DEFAULT_ROOT_LONG_DESC),
        Middleware.spec(:show_help,
                        help_flags: true,
                        usage_flags: true,
                        list_flags: true,
                        recursive_flags: true,
                        search_flags: true,
                        show_all_subtools_flags: true,
                        default_recursive: true,
                        allow_root_args: true,
                        show_source_path: true,
                        separate_sources: true,
                        use_pager: true,
                        fallback_execution: true),
        Middleware.spec(:show_root_version,
                        version_string: ::Toys::VERSION,
                        version_flag_desc: DEFAULT_VERSION_FLAG_DESC),
        Middleware.spec(:handle_usage_errors),
        Middleware.spec(:add_verbosity_flags),
      ]
    end

    ##
    # Returns a ModuleLookup for the default templates.
    #
    # @return [Toys::ModuleLookup]
    #
    def default_template_lookup
      ModuleLookup.new.add_path("toys/templates")
    end
  end
end
