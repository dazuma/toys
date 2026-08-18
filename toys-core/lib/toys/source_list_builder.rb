# frozen_string_literal: true

module Toys
  ##
  # A builder that collects a list of prioritized sources for the Loader.
  #
  # Not thread-safe. Callers should ensure that access is single-threaded or
  # synchronized.
  #
  class SourceListBuilder
    ##
    # Create a source list builder.
    #
    # @param git_cache [Toys::Utils::GitCache,nil] A custom GitCache instance
    #     to use to resolve git sources. Optional. If nil or not specified,
    #     constructs a default GitCache.
    # @param gems_util [Toys::Utils::Gems,nil] A custom Gems utility instance
    #     to use to resolve gem sources. Optional. If nil or not specified,
    #     constructs a default Gems utility.
    # @param sources [Array<SourceInfo>] An optional list of sources to
    #     populate into the source list initially.
    #
    def initialize(git_cache: nil, gems_util: nil, sources: nil)
      @git_cache = git_cache
      @gems_util = gems_util
      @sources = sources&.dup || []
      # An empty starting list leaves both bounds at 0, the same as if no
      # starting sources were provided at all.
      priorities = @sources.map(&:priority)
      @max_priority = priorities.max || 0
      @min_priority = priorities.min || 0
    end

    ##
    # The sources collected so far by this list builder, in the order they
    # were added. The result is a copy; modifying it does not affect this
    # builder.
    #
    # @return [Array<Toys::SourceInfo>]
    #
    def sources
      @sources.dup
    end

    ##
    # Add a tool file or directory to the source list.
    #
    # @param path [String] A single path to add.
    # @param high_priority [boolean] If true, add this path at the top of the
    #     priority list. Defaults to false, indicating the new path should be
    #     at the bottom of the priority list.
    # @param source_name [String] The source name that will be shown in
    #     documentation for tools loaded from this source. If omitted, a
    #     default unique string will be generated.
    # @param context_directory [String,nil,:path,:parent] The context directory
    #     for tools loaded from this path. You can pass a directory path as a
    #     string, `:path` to denote the given path, `:parent` to denote the
    #     given path's parent directory, or `nil` to denote no context.
    #     Defaults to `:parent`.
    #
    # @return [self]
    # @raise [Toys::ToolDefinitionError] if the given path does not point at
    #     a readable Ruby file or directory.
    #
    def add_path(path,
                 high_priority: false,
                 source_name: nil,
                 context_directory: :parent)
      source = SourceInfo.create_path_root(path,
                                           next_priority(high_priority),
                                           context_directory: context_directory,
                                           source_name: source_name)
      add_source(source, nil)
    end

    ##
    # Add a set of tool files/directories from a common directory to the source
    # list. The set of paths will be added at the same priority level and will
    # share a root.
    #
    # @param root_path [String] A root path to be seen as the root source. This
    #     should generally be a directory containing the paths to add.
    # @param relative_paths [String,Array<String>] One or more paths to add, as
    #     relative paths from the common root.
    # @param high_priority [boolean] If true, add the paths at the top of the
    #     priority list. Defaults to false, indicating the new paths should be
    #     at the bottom of the priority list.
    # @param source_name [String] The source name that will be shown in
    #     documentation for tools loaded from these sources. (Specifically,
    #     sets the name of the synthetic root source.) If omitted, a default
    #     unique string will be generated.
    # @param context_directory [String,nil,:path,:parent] The context directory
    #     for tools loaded from this path. You can pass a directory path as a
    #     string, `:path` to denote the given root path, `:parent` to denote
    #     the given root path's parent directory, or `nil` to denote no context.
    #     Defaults to `:path`.
    #
    # @return [self]
    # @raise [ArgumentError] if the root path is not a directory.
    # @raise [Toys::ToolDefinitionError] if any relative path does not point at
    #     a readable Ruby file or directory.
    #
    def add_path_set(root_path, relative_paths,
                     high_priority: false,
                     source_name: nil,
                     context_directory: :path)
      relative_paths = Array(relative_paths)
      root_source = SourceInfo.create_path_root(root_path,
                                                next_priority(high_priority),
                                                context_directory: context_directory,
                                                source_name: source_name)
      unless root_source.source_type == :directory
        raise ::ArgumentError, "Root path #{root_path.inspect} for add_path_set was not a directory"
      end
      add_source(root_source, relative_paths)
    end

    ##
    # Add a block to the source list.
    #
    # @param high_priority [boolean] If true, add this block at the top of the
    #     priority list. Defaults to false, indicating the block should be at
    #     the bottom of the priority list.
    # @param source_name [String] The source name that will be shown in
    #     documentation for tools loaded from this source. If omitted, a
    #     default unique string will be generated.
    # @param block [Proc] The source block, executed in the context of the
    #     tool DSL {Toys::DSL::Tool}.
    # @param context_directory [String,nil] The context directory for tools
    #     loaded from this block. You can pass a directory path as a string, or
    #     `nil` to denote no context. Defaults to `nil`.
    #
    # @return [self]
    #
    def add_block(high_priority: false,
                  source_name: nil,
                  context_directory: nil,
                  &block)
      source = SourceInfo.create_proc_root(block,
                                           next_priority(high_priority),
                                           context_directory: context_directory,
                                           source_name: source_name)
      add_source(source, nil)
    end

    ##
    # Add a git source to the source list.
    #
    # @param git_remote [String] The git repo URL
    # @param git_path [String] The path to the relevant file or directory in
    #     the repo.  Optional. Defaults to the entire repo.
    # @param git_commit [String] The git ref (i.e. SHA, tag, or branch name).
    #     Optional. Defaults to "HEAD".
    # @param update [boolean,Integer] Whether to update non-SHA commit
    #     references if they were previously loaded. This is useful, for
    #     example, if the commit is `HEAD` or a branch name. Pass `true` or
    #     `false` to specify whether to update, or an integer to update if
    #     last update was done at least that many seconds ago. Default is
    #     `false`.
    # @param high_priority [boolean] If true, add this path at the top of the
    #     priority list. Defaults to false, indicating the new path should be
    #     at the bottom of the priority list.
    # @param source_name [String] The source name that will be shown in
    #     documentation for tools loaded from this source. If omitted, a
    #     default unique string will be generated.
    # @param context_directory [String,nil] The context directory for tools
    #     loaded from this source. You can pass a directory path as a string,
    #     or `nil` to denote no context. Defaults to `nil`.
    #
    # @return [self]
    # @raise [Toys::ToolDefinitionError] if the specified git repo could not be
    #     accessed or did not contain valid toys files/directories.
    #
    def add_git(git_remote,
                git_path: nil,
                git_commit: nil,
                update: false,
                high_priority: false,
                source_name: nil,
                context_directory: nil)
      source = SourceInfo.create_git_root(git_remote, next_priority(high_priority),
                                          git_path: git_path,
                                          git_commit: git_commit,
                                          git_cache: @git_cache,
                                          update: update,
                                          context_directory: context_directory,
                                          source_name: source_name)
      add_source(source, nil)
    end

    ##
    # Add a gem source to the source list.
    #
    # @param gem_name [String] The name of the gem
    # @param gem_version [String,Array<String>] The version requirements.
    #     Optional. If not provided, any version is allowed.
    # @param gem_path [String] The path from the gem's toys directory to the
    #     relevant file or directory. Optional. If not provided, the entire
    #     toys directory is used.
    # @param gem_toys_dir [String] The name of the toys directory. Optional.
    #     Defaults to the directory specified in the gem's metadata, or the
    #     value "toys".
    # @param high_priority [boolean] If true, add this path at the top of the
    #     priority list. Defaults to false, indicating the new path should be
    #     at the bottom of the priority list.
    # @param source_name [String] The source name that will be shown in
    #     documentation for tools loaded from this source. If omitted, a
    #     default unique string will be generated.
    # @param context_directory [String,nil] The context directory for tools
    #     loaded from this source. You can pass a directory path as a string,
    #     or `nil` to denote no context. Defaults to `nil`.
    #
    # @return [self]
    # @raise [Toys::ToolDefinitionError] if the specified gem could not be
    #     activated or did not contain valid toys files/directories.
    #
    def add_gem(gem_name,
                gem_version: nil,
                gem_path: nil,
                gem_toys_dir: nil,
                high_priority: false,
                source_name: nil,
                context_directory: nil)
      source = SourceInfo.create_gem_root(gem_name, next_priority(high_priority),
                                          gem_version: gem_version,
                                          gem_path: gem_path,
                                          gem_toys_dir: gem_toys_dir,
                                          gems_util: @gems_util,
                                          context_directory: context_directory,
                                          source_name: source_name)
      add_source(source, nil)
    end

    private

    ##
    # Get the priority for a new source
    #
    # @return [Integer]
    #
    def next_priority(high_priority)
      high_priority ? @max_priority + 1 : @min_priority - 1
    end

    ##
    # Append a root source to the list. The relative_paths argument is a list
    # of paths relative to the root that should be loaded instead of the root
    # itself, or nil to load the root.
    #
    # Relative children are resolved strictly, so a path that is missing or is
    # not a tool file or directory raises here, naming the offending path,
    # rather than failing confusingly later at load time. Every member is
    # resolved before any is appended, so a failure partway through a set
    # leaves this builder untouched rather than half-populated.
    #
    def add_source(root_source, relative_paths)
      entries =
        if relative_paths
          relative_paths.map { |path| root_source.relative_child(path, lenient: false) }
        else
          [root_source]
        end
      @sources.concat(entries)
      priority = root_source.priority
      @max_priority = priority if priority > @max_priority
      @min_priority = priority if priority < @min_priority
      self
    end
  end
end
