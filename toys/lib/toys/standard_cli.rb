# frozen_string_literal: true

module Toys
  ##
  # Subclass of `Toys::CLI` configured for the behavior of the standard Toys
  # executable.
  #
  class StandardCLI < CLI
    ##
    # Standard toys configuration directory name.
    # @return [String]
    #
    CONFIG_DIR_NAME = ".toys"

    ##
    # Standard toys configuration file name.
    # @return [String]
    #
    CONFIG_FILE_NAME = ".toys.rb"

    ##
    # Standard index file name in a toys configuration.
    # @return [String]
    #
    INDEX_FILE_NAME = ".toys.rb"

    ##
    # Standard preload directory name in a toys configuration.
    # @return [String]
    #
    PRELOAD_DIR_NAME = ".preload"

    ##
    # Standard preload file name in a toys configuration.
    # @return [String]
    #
    PRELOAD_FILE_NAME = ".preload.rb"

    ##
    # Standard data directory name in a toys configuration.
    # @return [String]
    #
    DATA_DIR_NAME = ".data"

    ##
    # Standard lib directory name in a toys configuration.
    # @return [String]
    #
    LIB_DIR_NAME = ".lib"

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
    # Name of the toys path environment variable.
    # @return [String]
    #
    TOYS_PATH_ENV = "TOYS_PATH"

    ##
    # Create a standard CLI, configured with the appropriate paths and
    # middleware.
    #
    # @param custom_paths [String,Array<String>] Custom paths to use. If set,
    #     the CLI uses only the given paths. If not, the CLI will search for
    #     paths from the current directory and global paths.
    # @param include_builtins [boolean] Add the builtin tools. Default is true.
    # @param cur_dir [String,nil] Starting search directory for configs.
    #     Defaults to the current working directory.
    #
    def initialize(custom_paths: nil,
                   include_builtins: true,
                   cur_dir: nil)
      require "toys/utils/standard_ui"
      ui = Toys::Utils::StandardUI.new
      super(
        executable_name: EXECUTABLE_NAME,
        config_dir_name: CONFIG_DIR_NAME,
        config_file_name: CONFIG_FILE_NAME,
        index_file_name: INDEX_FILE_NAME,
        preload_file_name: PRELOAD_FILE_NAME,
        preload_dir_name: PRELOAD_DIR_NAME,
        data_dir_name: DATA_DIR_NAME,
        lib_dir_name: LIB_DIR_NAME,
        extra_delimiters: EXTRA_DELIMITERS,
        middleware_stack: default_middleware_stack,
        template_lookup: default_template_lookup,
        **ui.cli_args
      )
      if custom_paths
        Array(custom_paths).each { |path| add_config_path(path) }
      else
        add_current_directory_paths(cur_dir)
      end
      add_builtins if include_builtins
    end

    private

    ##
    # Add paths for builtin tools
    #
    def add_builtins
      builtins_path = ::File.join(::File.dirname(::File.dirname(__dir__)), "builtins")
      add_config_path(builtins_path, source_name: "(builtin tools)", context_directory: nil)
      self
    end

    ##
    # Add paths for the given current directory and its ancestors, plus the
    # global paths.
    #
    # @param cur_dir [String] The starting directory path, or nil to use the
    #     current directory
    # @return [self]
    #
    def add_current_directory_paths(cur_dir)
      cur_dir = skip_toys_dir(cur_dir || ::Dir.pwd, CONFIG_DIR_NAME)
      global_dirs = default_global_dirs
      add_search_path_hierarchy(start: cur_dir, terminate: global_dirs)
      global_dirs.each { |path| add_search_path(path) }
      self
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
    # Returns the default set of global config directories.
    #
    # @return [Array<String>]
    #
    def default_global_dirs
      paths = ::ENV[TOYS_PATH_ENV].to_s.split(::File::PATH_SEPARATOR)
      paths = [::Dir.home, "/etc"] if paths.empty?
      paths
        .compact
        .uniq
        .select { |path| ::File.directory?(path) && ::File.readable?(path) }
        .map { |path| ::File.realpath(::File.expand_path(path)) }
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
                        use_less: true,
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
