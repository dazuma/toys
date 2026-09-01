# frozen_string_literal: true

module Toys
  ##
  # Information about the source of a tool, such as the file, git repository,
  # or block that defined it.
  #
  # This object represents a source of tool information and definitions. Such a
  # source could include:
  #
  # * A toys directory
  # * A single toys file
  # * A file or directory loaded from git
  # * A file or directory loaded from a gem
  # * A block passed directly to the CLI
  # * A tool block within a toys file
  # * A subclass of Toys::Tool
  #
  # The SourceInfo provides information such as the tool's context directory,
  # and locates data and lib directories appropriate to the tool. It also
  # locates the tool's source code so it can be reported when an error occurs.
  #
  # Each tool has a unique SourceInfo with all the information specific to that
  # tool. Additionally, SourceInfo objects are arranged in a containment
  # hierarchy. For example, a SourceInfo object representing a toys files could
  # have a parent representing a toys directory, and an object representing a
  # tool block could have a parent representing an enclosing block or a file.
  #
  # Child SourceInfo objects generally inherit some attributes of their parent.
  # For example, the `.toys` directory in a project directory defines the
  # context directory as that project directory. Then all tools defined under
  # that directory will share that context directory, so all SourceInfo objects
  # descending from that root will inherit that value (unless it's changed
  # explicitly).
  #
  # SourceInfo objects can be obtained in the DSL from
  # {Toys::DSL::Tool#source_info} or at runtime by getting the
  # {Toys::Context::Key::TOOL_SOURCE} key. They are created internally during
  # CLI configuration and during loading.
  #
  class SourceInfo
    # @private
    DATA_DIR_NAME = ".data"

    # @private
    LIB_DIR_NAME = ".lib"

    # @private
    PRELOAD_DIR_NAME = ".preload"

    # @private
    PRELOAD_FILE_NAME = ".preload.rb"

    # @private
    INDEX_FILE_NAME = ".toys.rb"

    #### PUBLIC INTERFACE ####

    ##
    # The parent of this SourceInfo.
    #
    # @return [Toys::SourceInfo] The parent.
    # @return [nil] if this SourceInfo is a root.
    #
    attr_reader :parent

    ##
    # The root ancestor of this SourceInfo. This generally represents a source
    # that was added directly to a CLI in code.
    #
    # @return [Toys::SourceInfo] The root ancestor.
    #
    attr_reader :root

    ##
    # The priority of tools defined by this source. Higher values indicate a
    # higher priority. Lower priority values could be negative.
    #
    # @return [Integer] The priority.
    #
    attr_reader :priority

    ##
    # The context directory path set by this source or inherited from its
    # parent. Sometimes this is the directory containing the toplevel toys
    # file/directory, for example for the `toys` gem directory search that uses
    # the CLI `add_search*` methods. But other source types typically leave
    # this unset (nil).
    #
    # This is not affected by setting a custom context directory for a tool.
    #
    # @return [String] The context directory path.
    # @return [nil] if there is no context directory
    #
    attr_reader :context_directory

    ##
    # The source, which may be a path, a proc, or a class, depending on the
    # {#source_type}.
    #
    # @return [String] Path to the source file or directory.
    # @return [Proc] The block serving as the source.
    # @return [Class] The {Toys::Tool} subclass serving as the source.
    #
    attr_reader :source

    ##
    # The type of source. This could be:
    #
    # * `:file`, representing a single toys file. The {#source} will be the
    #   filesystem path to that file.
    # * `:directory`, representing a toys directory. The {#source} will be the
    #   filesystem path to that directory.
    # * `:proc`, representing a proc, which could be a toplevel block added
    #   directly to a CLI, a `tool` block within a toys file, or a block within
    #   another block. The {#source} will be the proc itself.
    # * `:subclass`, representing a subclass of {Toys::Tool}. The {#source}
    #   will be the class object.
    #
    # @return [:file,:directory,:proc,:subclass]
    #
    attr_reader :source_type

    ##
    # The path of the current source file or directory.
    #
    # This could be set even if {#source_type} is `:proc`, if that proc is
    # defined within a toys file. The only time this is not set is if the
    # source is added directly to a CLI in a code block.
    #
    # @return [String] The source path
    # @return [nil] if this source has no file system path.
    #
    attr_reader :source_path

    ##
    # The source proc. This is set if {#source_type} is `:proc`.
    #
    # @return [Proc] The source proc
    # @return [nil] if this source has no proc.
    #
    attr_reader :source_proc

    ##
    # The source subclass. This is set if {#source_type} is `:subclass`.
    #
    # @return [Class] The source subclass
    # @return [nil] if this source is not a subclass.
    #
    attr_reader :source_subclass

    ##
    # The origin of this source, describing where its content came from: the
    # local file system, a git repository, a Ruby gem, or a block of code.
    #
    # An origin is fixed when a source spec is resolved. A source created by
    # descending from another, whether by walking a directory or by entering a
    # block or a subclass, shares its parent origin object.
    #
    # Origins are one of the following types:
    # * {Toys::SourceInfo::Origin::Local} for a local file or directory
    # * {Toys::SourceInfo::Origin::Git} for a git repository
    # * {Toys::SourceInfo::Origin::Gem} for a RubyGem
    # * {Toys::SourceInfo::Origin::Block} for a bare Ruby code block
    #
    # @return [Toys::SourceInfo::Origin::Base]
    #
    attr_reader :origin

    ##
    # A user-visible name of this source.
    #
    # @return [String]
    #
    attr_reader :source_name
    alias to_s source_name

    ##
    # Locate the given data file or directory and return an absolute path.
    #
    # @param path [String] The relative path to find
    # @param type [nil,:file,:directory] Type of file system object to find,
    #     or nil (the default) to return any type.
    # @return [String] Absolute path of the resulting data.
    # @return [nil] if the data was not found.
    #
    def find_data(path, type: nil)
      if @source_type == :directory
        data_dir = ::File.join(@source_path, DATA_DIR_NAME)
        if ::File.directory?(data_dir) && ::File.readable?(data_dir)
          full_path = ::File.join(data_dir, path)
          case type
          when :file
            return full_path if ::File.file?(full_path)
          when :directory
            return full_path if ::File.directory?(full_path)
          else
            return full_path if ::File.readable?(full_path)
          end
        end
      end
      parent&.find_data(path, type: type)
    end

    ##
    # Find lib paths in this source and all ancestors, in order from most to
    # least significant.
    #
    # @return [Array<String>] Directory paths in order
    #
    def find_lib_paths
      results = []
      if @source_type == :directory
        lib_dir = ::File.join(@source_path, LIB_DIR_NAME)
        results << lib_dir if ::File.directory?(lib_dir) && ::File.readable?(lib_dir)
      end
      results += parent.find_lib_paths if parent
      results
    end

    ##
    # Find all files to preload in this source only, not including ancestors.
    #
    # @return [Array<String>] File paths in order
    #
    def find_preload_files
      results = []
      if @source_type == :directory
        preload_file = ::File.join(@source_path, PRELOAD_FILE_NAME)
        results << preload_file if ::File.file?(preload_file) && ::File.readable?(preload_file)
        preload_dir = ::File.join(@source_path, PRELOAD_DIR_NAME)
        if ::File.directory?(preload_dir) && ::File.readable?(preload_dir)
          ::Dir.entries(preload_dir).sort.each do |child|
            next unless ::File.extname(child) == ".rb"
            preload_file = ::File.join(preload_dir, child)
            results << preload_file if ::File.file?(preload_file) && ::File.readable?(preload_file)
          end
        end
      end
      results
    end

    #### RESOLUTION ####

    class << self
      ##
      # Resolve a source spec into a SourceInfo, performing the file system
      # access, git fetch, or gem activation that the spec describes.
      #
      # If a parent source is given, the result is a child of it, and inherits
      # the parent's priority and context directory; the spec's own context
      # directory and any explicit priority are ignored. If no parent is given,
      # the result is a root, and a priority is required.
      #
      # Each kind of spec drops the fields it does not own, so for example a
      # path source resolved under a git parent carries no git information.
      #
      # @private This interface is internal and subject to change without warning.
      #
      def resolve(spec, parent: nil, priority: nil, git_cache: nil, gems_util: nil)
        if parent
          priority = parent.priority
        elsif priority.nil?
          raise ::ArgumentError, "A priority is required when resolving a root source"
        end
        case spec
        when SourceSpec::Path
          resolve_path_spec(spec, parent, priority)
        when SourceSpec::Git
          resolve_git_spec(spec, parent, priority, git_cache)
        when SourceSpec::Gem
          resolve_gem_spec(spec, parent, priority, gems_util)
        when SourceSpec::Block
          raise ::ArgumentError, "A block spec cannot be resolved as a child" if parent
          resolve_block_spec(spec, priority)
        else
          raise ::ArgumentError, "Unrecognized source spec: #{spec.inspect}"
        end
      end

      private

      def resolve_path_spec(spec, parent, priority)
        if parent
          if spec.relative_paths
            raise ::ArgumentError, "A path spec with relative paths cannot be resolved as a child"
          end
          case parent.origin
          when Origin::Git
            raise ToolSourceError, "Git source #{parent.source_name} tried to load from the local file system"
          when Origin::Gem
            raise ToolSourceError, "Gem source #{parent.source_name} tried to load from the local file system"
          end
        end
        source_path, type = check_path(spec.path, false)
        context_directory = spec.context_directory || parent&.context_directory
        origin = Origin::Local.new(source_path)
        new(parent, priority, context_directory, type, origin, ".", nil, nil, spec.source_name)
      end

      def resolve_git_spec(spec, parent, priority, git_cache)
        parent_origin = parent&.origin
        git_remote = spec.remote
        git_commit = spec.commit
        if parent_origin.is_a?(Origin::Git)
          git_remote ||= parent_origin.remote
          git_commit ||= parent_origin.commit
        end
        raise ToolSourceError, "Git remote not specified" unless git_remote
        git_commit, git_path, source_path =
          resolve_git_info(git_cache, git_remote, spec.path, git_commit, spec.update)
        source_path, type = check_path(source_path, false)
        context_directory = spec.context_directory || parent&.context_directory
        origin = Origin::Git.new(source_path, git_remote, git_commit, git_path)
        new(parent, priority, context_directory, type, origin, ".", nil, nil, spec.source_name)
      end

      def resolve_gem_spec(spec, parent, priority, gems_util)
        gem_version, gem_path, source_path =
          resolve_gem_info(gems_util, spec.name, spec.version, spec.path, spec.toys_dir)
        source_path, type = check_path(source_path, false)
        context_directory = spec.context_directory || parent&.context_directory
        origin = Origin::Gem.new(source_path, spec.name, gem_version, gem_path)
        new(parent, priority, context_directory, type, origin, ".", nil, nil, spec.source_name)
      end

      def resolve_block_spec(spec, priority)
        new(nil, priority, spec.context_directory, :proc, Origin::Block.new, ".", spec.block, nil, spec.source_name)
      end
    end

    #### CHILD OBJECT CREATORS ####

    ##
    # Create a child SourceInfo relative to the parent path.
    #
    # @private This interface is internal and subject to change without warning.
    #
    def relative_child(filename, source_name: nil, lenient: true)
      raise ::ArgumentError, "relative_child is valid only on a directory source" unless source_type == :directory
      child_path, type = SourceInfo.check_path(::File.join(source_path, filename), lenient)
      return nil unless child_path
      child_relative_path = Origin.join_relative(@relative_path, filename)
      SourceInfo.new(self, priority, context_directory, type,
                     @origin, child_relative_path, nil, nil,
                     source_name)
    end

    ##
    # Create a child SourceInfo for an index tool file, or nil if not found or
    # not applicable.
    #
    # @private This interface is internal and subject to change without warning.
    #
    def index_child(source_name: nil)
      raise ::ArgumentError, "index_child is valid only on a directory source" unless source_type == :directory
      relative_child(INDEX_FILE_NAME, source_name: source_name)
    end

    ##
    # Create a proc child SourceInfo
    #
    # @private This interface is internal and subject to change without warning.
    #
    def proc_child(child_proc, source_name: nil)
      source_name ||= self.source_name
      SourceInfo.new(self, priority, context_directory, :proc,
                     @origin, @relative_path, child_proc, nil,
                     source_name)
    end

    ##
    # Create a subclass child SourceInfo
    #
    # @private This interface is internal and subject to change without warning.
    #
    def subclass_child(subclass, source_name: nil)
      unless [:file, :subclass].include?(source_type)
        raise ::ArgumentError, "subclass_child is valid only on a file or subclass source"
      end
      SourceInfo.new(self, priority, context_directory, :subclass,
                     @origin, @relative_path, nil, subclass,
                     source_name)
    end

    #### INTERNAL CONSTRUCTOR ####

    ##
    # Create a SourceInfo.
    # This lower-level interface should be called only from within the class.
    # External callers should use the factory class methods which have keyword
    # arguments and are safer and more readable.
    #
    # @private This interface is internal and subject to change without warning.
    #
    def initialize(parent, priority, context_directory,
                   source_type, origin, relative_path, source_proc, source_subclass,
                   source_name)
      @parent = parent
      @root = parent&.root || self
      @priority = priority
      @context_directory = context_directory
      @source_type = source_type
      @origin = origin
      @relative_path = relative_path
      @source_path = origin.joined_path(relative_path)
      @source = case source_type
                when :proc
                  source_proc
                when :subclass
                  source_subclass
                else
                  @source_path
                end
      @source_proc = source_proc
      @source_subclass = source_subclass
      @source_name = source_name || default_source_name
    end

    #### INTERNAL HELPERS ####

    @utils_creation_mutex = ::Mutex.new
    @default_git_cache = nil
    @default_gems_util = nil

    class << self
      ##
      # Check a path and determine the canonical path and type.
      #
      # @private This interface is internal and subject to change without warning.
      #
      def check_path(path, lenient)
        path = ::File.expand_path(path)
        unless ::File.readable?(path)
          raise ToolSourceError, "Cannot read: #{path}" unless lenient
          return [nil, nil]
        end
        if ::File.file?(path)
          unless ::File.extname(path) == ".rb"
            raise ToolSourceError, "File is not a ruby file: #{path}" unless lenient
            return [nil, nil]
          end
          [path, :file]
        elsif ::File.directory?(path)
          [path, :directory]
        else
          raise ToolSourceError, "Not a ruby file or directory: #{path}" unless lenient
          [nil, nil]
        end
      end

      ##
      # Resolve a gem and version constraints and get the install directory.
      #
      # @private This interface is internal and subject to change without warning.
      #
      def resolve_gem_info(gems_util, gem_name, gem_versions, gem_path, gem_toys_dir)
        require "toys/utils/gems"
        begin
          (gems_util || default_gems_util).activate(gem_name, *gem_versions)
        rescue ::Toys::Utils::Gems::ActivationFailedError => e
          raise ToolSourceError, e.message
        end
        gem_spec = ::Gem.loaded_specs[gem_name]
        raise ToolSourceError, "Unable to find gem #{gem_name}" unless gem_spec&.gem_dir
        gem_toys_dir ||= gem_spec.metadata["toys_dir"] || "toys"
        gem_path = gem_path.to_s.empty? ? gem_toys_dir : ::File.join(gem_toys_dir, gem_path)
        source_path = ::File.join(gem_spec.gem_dir, gem_path)
        [gem_spec.version, gem_path, source_path]
      end

      ##
      # Resolve contents from the git cache and get the directory.
      #
      # @private This interface is internal and subject to change without warning.
      #
      def resolve_git_info(git_cache, git_remote, git_path, git_commit, update)
        require "toys/utils/git_cache"
        git_commit ||= "HEAD"
        git_path ||= ""
        git_cache ||= default_git_cache
        source_path = begin
          git_cache.get(git_remote, path: git_path, commit: git_commit, update: update)
        rescue ::Toys::Utils::GitCache::Error => e
          raise ToolSourceError, "Unable to access git repo #{git_remote}: #{e.message}"
        end
        [git_commit, git_path, source_path]
      end

      private

      def default_git_cache
        @utils_creation_mutex.synchronize do
          @default_git_cache ||= begin
            require "toys/utils/git_cache"
            Utils::GitCache.new
          end
        end
      end

      def default_gems_util
        @utils_creation_mutex.synchronize do
          @default_gems_util ||= begin
            require "toys/utils/gems"
            Utils::Gems.new
          end
        end
      end
    end

    private

    def default_source_name
      case source_type
      when :proc
        "(code block #{source_proc.object_id})"
      when :subclass
        default_subclass_source_name
      else
        @origin.describe(@relative_path)
      end
    end

    def default_subclass_source_name
      name = source_subclass.name.split("::").last
      walk = parent
      while walk&.source_type == :subclass
        name = "#{walk.source_subclass.name.split('::').last}::#{name}"
        walk = walk.parent
      end
      name = "class #{name}"
      walk ? "#{walk.source_name} (#{name})" : name
    end
  end
end
