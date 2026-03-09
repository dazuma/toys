# frozen_string_literal: true

module Toys
  module Utils
    ##
    # A class that provides tools for working with the XDG Base Directory
    # Specification.
    #
    # This class provides utility methods that locate base directories and
    # search paths for application state, configuration, caches, and other
    # data, according to the [XDG Base Directory Spec version
    # 0.8](https://specifications.freedesktop.org/basedir/0.8/).
    #
    # Tools can use the `:xdg` mixin for convenient access to this class.
    #
    # ### Example
    #
    #     require "toys/utils/xdg"
    #
    #     xdg = Toys::Utils::XDG.new
    #
    #     # Get config file paths, in order from most to least important
    #     config_files = xdg.lookup_config("my-config.toml")
    #     config_files.each { |path| read_my_config(path) }
    #
    # ### Windows operation
    #
    # The Spec assumes a unix-like environment, and cannot be applied directly
    # to Windows without modification. In general, this class will function on
    # Windows, but with the following caveats:
    #
    #  *   All file paths must use Windows-style absolute paths, beginning with
    #      the drive letter.
    #  *   Environment variables that can contain multiple paths (`XDG_*_DIRS`)
    #      use the Windows path delimiter (`;`) rather than the unix path
    #      delimiter (`:`).
    #  *   Defaults for home directories (`XDG_*_HOME`) will follow unix
    #      conventions, using subdirectories under the user's profile directory
    #      rather than the Windows known folder paths.
    #  *   Defaults for search paths (`XDG_*_DIRS`) will be empty and will not
    #      use the Windows known folder paths.
    #
    class XDG
      ##
      # An error raised in certain cases when a lookup fails.
      #
      class Error < ::StandardError
      end

      ##
      # Create an instance of XDG.
      #
      # @param env [Hash{String=>String}] the environment variables. Normally,
      #     you can omit this argument, as it will default to `::ENV`.
      #
      def initialize(env: ::ENV)
        require "fileutils"
        @env = env
      end

      ##
      # Returns the absolute path to the current user's home directory.
      #
      # @return [String]
      #
      def home_dir
        @home_dir ||= validate_dir_env("HOME") || ::Dir.home
      end

      ##
      # Returns the absolute path to the single base directory relative to
      # which user-specific data files should be written.
      #
      # Corresponds to the value of the `$XDG_DATA_HOME` environment variable
      # and its defaults according to the XDG Base Directory Spec.
      #
      # @return [String]
      #
      def data_home
        @data_home ||= validate_dir_env("XDG_DATA_HOME") || ::File.join(home_dir, ".local", "share")
      end

      ##
      # Returns the absolute path to the single base directory relative to
      # which user-specific configuration files should be written.
      #
      # Corresponds to the value of the `$XDG_CONFIG_HOME` environment variable
      # and its defaults according to the XDG Base Directory Spec.
      #
      # @return [String]
      #
      def config_home
        @config_home ||= validate_dir_env("XDG_CONFIG_HOME") || ::File.join(home_dir, ".config")
      end

      ##
      # Returns the absolute path to the single base directory relative to
      # which user-specific state files should be written.
      #
      # Corresponds to the value of the `$XDG_STATE_HOME` environment variable
      # and its defaults according to the XDG Base Directory Spec.
      #
      # @return [String]
      #
      def state_home
        @state_home ||= validate_dir_env("XDG_STATE_HOME") || ::File.join(home_dir, ".local", "state")
      end

      ##
      # Returns the absolute path to the single base directory relative to
      # which user-specific non-essential (cached) data should be written.
      #
      # Corresponds to the value of the `$XDG_CACHE_HOME` environment variable
      # and its defaults according to the XDG Base Directory Spec.
      #
      # @return [String]
      #
      def cache_home
        @cache_home ||= validate_dir_env("XDG_CACHE_HOME") || ::File.join(home_dir, ".cache")
      end

      ##
      # Returns the absolute path to the single base directory relative to
      # which user-specific executable files may be written.
      #
      # Returns the value of `$HOME/.local/bin` as specified by the XDG Base
      # Directory Spec.
      #
      # @return [String]
      #
      def executable_home
        @executable_home ||= ::File.join(home_dir, ".local", "bin")
      end

      ##
      # Returns the set of preference ordered base directories relative to
      # which data files should be searched, as an array of absolute paths.
      # The array is ordered from most to least important, and does _not_
      # include the data home directory.
      #
      # Corresponds to the value of the `$XDG_DATA_DIRS` environment variable
      # and its defaults according to the XDG Base Directory Spec.
      #
      # @return [Array<String>]
      #
      def data_dirs
        @data_dirs ||= validate_dirs_env("XDG_DATA_DIRS") ||
                       validate_dirs(["/usr/local/share", "/usr/share"])
      end

      ##
      # Returns the set of preference ordered base directories relative to
      # which configuration files should be searched, as an array of absolute
      # paths. The array is ordered from most to least important, and does
      # _not_ include the config home directory.
      #
      # Corresponds to the value of the `$XDG_CONFIG_DIRS` environment variable
      # and its defaults according to the XDG Base Directory Spec.
      #
      # @return [Array<String>]
      #
      def config_dirs
        @config_dirs ||= validate_dirs_env("XDG_CONFIG_DIRS") ||
                         validate_dirs(["/etc/xdg"])
      end

      ##
      # Returns the absolute path to the single base directory relative to
      # which user-specific runtime files and other file objects should be
      # placed.
      #
      # Corresponds to the value of the `$XDG_RUNTIME_DIR` environment variable
      # according to the XDG Base Directory Spec.
      #
      # **Important:** Returns `nil` if the `$XDG_RUNTIME_DIR` environment
      # variable is unset or invalid. In such a case, it is the caller's
      # responsibility to determine a fallback strategy, as this library cannot
      # by itself implement a compliant fallback without OS help.
      #
      # @return [String,nil]
      #
      def runtime_dir
        @runtime_dir = validate_dir_env("XDG_RUNTIME_DIR") unless defined? @runtime_dir
        @runtime_dir
      end

      ##
      # Returns the absolute path to the single base directory relative to
      # which user-specific runtime files and other file objects should be
      # placed.
      #
      # Corresponds to the value of the `$XDG_RUNTIME_DIR` environment variable
      # according to the XDG Base Directory Spec.
      #
      # Raises {Toys::Utils::XDG::Error} if the `$XDG_RUNTIME_DIR` environment
      # variable is unset or invalid. Unlike {#runtime_dir}, does not return
      # nil.
      #
      # @return [String]
      #
      def runtime_dir!
        runtime_dir || raise(::Toys::Utils::XDG::Error, "XDG_RUNTIME_DIR is unset or invalid")
      end

      ##
      # Searches the data directories for an object with the given relative
      # path, and returns an array of absolute paths to all objects found in
      # all data directories (i.e. {#data_home} and {#data_dirs}), in order
      # from most to least important. Returns the empty array if no suitable
      # objects are found.
      #
      # If multiple objects are found, the caller should implement its own
      # logic to resolve them. For example, it can select the first (most
      # important) object, or implement logic to combine the contents.
      #
      # @param path [String] Relative path of the object to search for
      # @param type [String,Symbol,Array<String,Symbol>] The type(s) of objects
      #     to find. You can specify any of the types defined by
      #     [File::Stat#ftype](https://ruby-doc.org/core/File/Stat.html#method-i-ftype),
      #     such as `file` or `directory`, or the special type `any`. Types can
      #     be specified as strings or the  corresponding symbols. If this
      #     argument is not provided, the default of `file` is used.
      # @return [Array<String>]
      #
      def lookup_data(path, type: :file)
        lookup_internal([data_home] + data_dirs, path, type)
      end

      ##
      # Searches the config directories for an object with the given relative
      # path, and returns an array of absolute paths to all objects found in
      # all config directories (i.e. {#config_home} and {#config_dirs}), in
      # order from most to least important. Returns the empty array if no
      # suitable objects are found.
      #
      # If multiple objects are found, the caller should implement its own
      # logic to resolve them. For example, it can select the first (most
      # important) object, or implement logic to combine the contents.
      #
      # @param path [String] Relative path of the object to search for
      # @param type [String,Symbol,Array<String,Symbol>] The type(s) of objects
      #     to find. You can specify any of the types defined by
      #     [File::Stat#ftype](https://ruby-doc.org/core/File/Stat.html#method-i-ftype),
      #     such as `file` or `directory`, or the special type `any`. Types can
      #     be specified as strings or the  corresponding symbols. If this
      #     argument is not provided, the default of `file` is used.
      # @return [Array<String>]
      #
      def lookup_config(path, type: :file)
        lookup_internal([config_home] + config_dirs, path, type)
      end

      ##
      # Searches the state directory ({#state_home}) for an object with the
      # given relative path, and returns an array of zero or one absolute paths
      # to any found object. Because the XDG basedir spec does not provide for
      # a list of fallback directories for state files (i.e. there is no
      # `XDG_STATE_DIRS` variable or list of default paths), this will return a
      # maximum of one result. However, it returns an array for consistency
      # with the {#lookup_data} and {#lookup_config} methods.
      #
      # @param path [String] Relative path of the object to search for
      # @param type [String,Symbol,Array<String,Symbol>] The type(s) of objects
      #     to find. You can specify any of the types defined by
      #     [File::Stat#ftype](https://ruby-doc.org/core/File/Stat.html#method-i-ftype),
      #     such as `file` or `directory`, or the special type `any`. Types can
      #     be specified as strings or the  corresponding symbols. If this
      #     argument is not provided, the default of `file` is used.
      # @return [Array<String>]
      #
      def lookup_state(path, type: :file)
        lookup_internal([state_home], path, type)
      end

      ##
      # Searches the cache directory ({#cache_home}) for an object with the
      # given relative path, and returns an array of zero or one absolute paths
      # to any found object. Because the XDG basedir spec does not provide for
      # a list of fallback directories for cache files (i.e. there is no
      # `XDG_CACHE_DIRS` variable or list of default paths), this will return a
      # maximum of one result. However, it returns an array for consistency
      # with the {#lookup_data} and {#lookup_config} methods.
      #
      # @param path [String] Relative path of the object to search for
      # @param type [String,Symbol,Array<String,Symbol>] The type(s) of objects
      #     to find. You can specify any of the types defined by
      #     [File::Stat#ftype](https://ruby-doc.org/core/File/Stat.html#method-i-ftype),
      #     such as `file` or `directory`, or the special type `any`. Types can
      #     be specified as strings or the  corresponding symbols. If this
      #     argument is not provided, the default of `file` is used.
      # @return [Array<String>]
      #
      def lookup_cache(path, type: :file)
        lookup_internal([cache_home], path, type)
      end

      ##
      # Returns the absolute path to a directory under {#data_home}, creating
      # it if it doesn't already exist.
      #
      # @param path [String] The relative path to the subdir within the base
      #     data directory.
      # @return [String] The absolute path to the subdir.
      # @raise [SystemCallError] If a non-directory already exists there. It is
      #     unspecified which specific error will be raised; it typically could
      #     be `Errno::EEXIST` or `Errno::ENOTDIR`.
      #
      def ensure_data_subdir(path)
        ensure_subdir_internal(data_home, path)
      end

      ##
      # Returns the absolute path to a directory under {#config_home}, creating
      # it if it doesn't already exist.
      #
      # @param path [String] The relative path to the subdir within the base
      #     config directory.
      # @return [String] The absolute path to the subdir.
      # @raise [SystemCallError] If a non-directory already exists there. It is
      #     unspecified which specific error will be raised; it typically could
      #     be `Errno::EEXIST` or `Errno::ENOTDIR`.
      #
      def ensure_config_subdir(path)
        ensure_subdir_internal(config_home, path)
      end

      ##
      # Returns the absolute path to a directory under {#state_home}, creating
      # it if it doesn't already exist.
      #
      # @param path [String] The relative path to the subdir within the base
      #     state directory.
      # @return [String] The absolute path to the subdir.
      # @raise [SystemCallError] If a non-directory already exists there. It is
      #     unspecified which specific error will be raised; it typically could
      #     be `Errno::EEXIST` or `Errno::ENOTDIR`.
      #
      def ensure_state_subdir(path)
        ensure_subdir_internal(state_home, path)
      end

      ##
      # Returns the absolute path to a directory under {#cache_home}, creating
      # it if it doesn't already exist.
      #
      # @param path [String] The relative path to the subdir within the base
      #     cache directory.
      # @return [String] The absolute path to the subdir.
      # @raise [SystemCallError] If a non-directory already exists there. It is
      #     unspecified which specific error will be raised; it typically could
      #     be `Errno::EEXIST` or `Errno::ENOTDIR`.
      #
      def ensure_cache_subdir(path)
        ensure_subdir_internal(cache_home, path)
      end

      private

      ##
      # Given an environment variable name, returns the value if it is a legal
      # absolute path, otherwise returns nil. Used to interpret `XDG_*_HOME`
      # variables.
      #
      def validate_dir_env(name)
        path = @env[name].to_s
        ::File.absolute_path?(path) ? path : nil
      end

      ##
      # Given an environment variable name, returns nil if unset or empty,
      # otherwise returns a (possibly empty) array of the valid paths.
      #
      def validate_dirs_env(name)
        raw_value = @env[name].to_s
        return nil if raw_value.empty?
        validate_dirs(raw_value.split(::File::PATH_SEPARATOR))
      end

      ##
      # Given an array of paths, returns a (possibly empty) array of which ones
      # are valid absolute paths.
      #
      def validate_dirs(paths)
        paths.find_all { |path| ::File.absolute_path?(path) }
      end

      ##
      # Given an array of directories, a relative path, and an array of types,
      # find and return all objects found as absolute paths.
      #
      def lookup_internal(dirs, path, types)
        results = []
        types = Array(types).map(&:to_s)
        any_type = types.include?("any")
        dirs.each do |dir|
          to_check = ::File.join(dir, path)
          stat = ::File.stat(to_check) rescue nil # rubocop:disable Style/RescueModifier
          if stat&.readable? && (any_type || types.include?(stat.ftype))
            results << to_check
          end
        end
        results
      end

      ##
      # Ensure directory exists, and return its absolute path.
      #
      def ensure_subdir_internal(base_dir, path)
        path = ::File.join(base_dir, path)
        ::FileUtils.mkdir_p(path, mode: 0o700)
        path
      end
    end
  end
end
