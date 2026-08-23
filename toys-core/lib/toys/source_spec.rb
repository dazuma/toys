# frozen_string_literal: true

module Toys
  ##
  # A source spec is an unresolved description of a source: its kind, and the
  # information needed to locate it.
  #
  # Source specs cover the sources added to a {Toys::SourceList}, and the
  # sources declared from within a toys file using the `load`, `load_git`, and
  # `load_gem` directives. (A source that a {Toys::Loader} finds by walking a
  # directory has no source spec.)
  #
  # A source spec says only what to load; it performs no filesystem access, no
  # git fetch, and no gem activation. Those happen later, when a loader
  # resolves the spec into a {Toys::SourceInfo}. Create specs using the
  # factory methods {Toys::SourceSpec.path}, {Toys::SourceSpec.git},
  # {Toys::SourceSpec.gem}, and {Toys::SourceSpec.block}, each of which
  # returns an instance of the corresponding subclass of
  # {Toys::SourceSpec::Base}.
  #
  # Source specs are immutable and compare by value, so two specs describing
  # the same source are equal and hash alike. (A block spec's proc compares by
  # identity.)
  #
  module SourceSpec
    class << self
      ##
      # Create a spec for a file system path.
      #
      # @param path [String] Path to a tool file or directory.
      # @param relative_paths [String,Array<String>,nil] If provided, the given
      #     path is treated as a root directory, and these paths, relative to
      #     it, are the sources actually loaded. Pass `nil` (the default) to
      #     load the path itself. Note that `nil` and the empty array mean
      #     different things: the empty array loads nothing from the root.
      # @param context_directory [String,nil,:path,:parent] The context
      #     directory for tools loaded from this source. You can pass a
      #     directory path as a string, `:path` to denote the given path,
      #     `:parent` to denote the given path's parent directory, or `nil` to
      #     denote no context. Defaults to `:parent`.
      # @param source_name [String,nil] The source name that will be shown in
      #     documentation for tools loaded from this source. If omitted, a
      #     default is generated at resolution time.
      # @return [Toys::SourceSpec::Path]
      # @raise [ArgumentError] if an argument is not a legal value.
      #
      def path(path, relative_paths: nil, context_directory: :parent, source_name: nil)
        Path.new(path, relative_paths, context_directory, source_name)
      end

      ##
      # Create a spec for a git repository.
      #
      # @param remote [String,nil] The git repo URL, or `nil` to inherit the
      #     remote from the source doing the loading. (A `nil` remote with no
      #     such source fails at resolution time, not here.)
      # @param path [String,nil] The path within the repo to the file or
      #     directory to load. Optional. Defaults to the root of the repo.
      # @param commit [String,nil] The git ref (i.e. SHA, tag, or branch name).
      #     Optional. Defaults to the commit of the source doing the loading,
      #     or to `"HEAD"`.
      # @param update [boolean,Integer] Whether to update non-SHA commit
      #     references if they were previously loaded. Pass `true` or `false`
      #     to specify whether to update, or an integer to update if the last
      #     update was done at least that many seconds ago. Default is `false`.
      # @param context_directory [String,nil] The context directory for tools
      #     loaded from this source. You can pass a directory path as a string,
      #     or `nil` to denote no context. Defaults to `nil`.
      # @param source_name [String,nil] The source name that will be shown in
      #     documentation for tools loaded from this source. If omitted, a
      #     default is generated at resolution time.
      # @return [Toys::SourceSpec::Git]
      # @raise [ArgumentError] if an argument is not a legal value.
      #
      def git(remote, path: nil, commit: nil, update: false, context_directory: nil, source_name: nil)
        Git.new(remote, path, commit, update, context_directory, source_name)
      end

      ##
      # Create a spec for a gem.
      #
      # @param name [String] The name of the gem.
      # @param version [String,Array<String>,nil] Version requirements for the
      #     gem. Optional. If not provided, any version is allowed.
      # @param path [String,nil] The path from the gem's toys directory to the
      #     relevant file or directory. Optional. If not provided, the entire
      #     toys directory is used.
      # @param toys_dir [String,nil] The name of the gem's toys directory.
      #     Optional. Defaults to the directory specified in the gem's
      #     metadata, or the value `"toys"`.
      # @param context_directory [String,nil] The context directory for tools
      #     loaded from this source. You can pass a directory path as a string,
      #     or `nil` to denote no context. Defaults to `nil`.
      # @param source_name [String,nil] The source name that will be shown in
      #     documentation for tools loaded from this source. If omitted, a
      #     default is generated at resolution time.
      # @return [Toys::SourceSpec::Gem]
      # @raise [ArgumentError] if an argument is not a legal value.
      #
      def gem(name, version: nil, path: nil, toys_dir: nil, context_directory: nil, source_name: nil)
        Gem.new(name, version, path, toys_dir, context_directory, source_name)
      end

      ##
      # Create a spec for a block of DSL code.
      #
      # @param context_directory [String,nil] The context directory for tools
      #     loaded from this source. You can pass a directory path as a string,
      #     or `nil` to denote no context. Defaults to `nil`.
      # @param source_name [String,nil] The source name that will be shown in
      #     documentation for tools loaded from this source. If omitted, a
      #     default is generated at resolution time.
      # @param block [Proc] The source block, executed in the context of the
      #     tool DSL {Toys::DSL::Tool}.
      # @return [Toys::SourceSpec::Block]
      # @raise [ArgumentError] if an argument is not a legal value.
      #
      def block(context_directory: nil, source_name: nil, &block)
        Block.new(block, context_directory, source_name)
      end
    end

    ##
    # The base class of a source spec, holding the attributes common to every
    # kind, and implementing equality.
    #
    # Do not instantiate this class directly. Use one of the factory methods
    # such as {Toys::SourceSpec.path}.
    #
    class Base
      ##
      # Create a source spec base.
      # This argument list is subject to change. Use the factory methods such
      # as {Toys::SourceSpec.path} instead.
      #
      # @private
      #
      def initialize(context_directory, source_name)
        validate_context_directory(context_directory)
        @context_directory = context_directory
        @source_name = source_name
        freeze
      end

      ##
      # The context directory for tools loaded from this source, or a symbol
      # directing how to compute it. This is honored only when the spec is
      # resolved as a root; a child source inherits its parent's context
      # directory.
      #
      # @return [String,nil,:path,:parent]
      #
      attr_reader :context_directory

      ##
      # The user-visible name for tools loaded from this source, or `nil` to
      # generate a default at resolution time.
      #
      # @return [String,nil]
      #
      attr_reader :source_name

      ##
      # Source specs compare by value. Specs of different kinds are never
      # equal, even if their common attributes match.
      #
      # @param other [Object]
      # @return [boolean]
      #
      def ==(other)
        other.class.equal?(self.class) && other.equality_fields == equality_fields
      end
      alias eql? ==

      ##
      # @return [Integer]
      #
      def hash
        equality_fields.hash
      end

      protected

      ##
      # The fields that determine equality, in a fixed order. Subclasses
      # append their own fields to this list.
      #
      # @private
      #
      def equality_fields
        [@context_directory, @source_name]
      end

      private

      ##
      # Raise unless the given context directory is legal for this kind of
      # spec. Only {Toys::SourceSpec::Path} recognizes the symbolic forms.
      #
      def validate_context_directory(context_directory)
        return if context_directory.nil? || context_directory.is_a?(::String)
        raise ::ArgumentError, "Illegal context_directory: #{context_directory.inspect}"
      end
    end

    ##
    # A spec for a source located by file system path.
    #
    class Path < Base
      ##
      # Create a path spec.
      # This argument list is subject to change. Use
      # {Toys::SourceSpec.path} instead.
      #
      # @private
      #
      def initialize(path, relative_paths, context_directory, source_name)
        @path = path
        @relative_paths = relative_paths.nil? ? nil : Array(relative_paths).dup.freeze
        super(context_directory, source_name)
      end

      ##
      # The file system path. If {#relative_paths} is non-nil, this is the root
      # directory those paths are relative to.
      #
      # @return [String]
      #
      attr_reader :path

      ##
      # The paths to load, relative to {#path}, or `nil` to load {#path}
      # itself. The empty array means load nothing from the root.
      #
      # @return [Array<String>,nil]
      #
      attr_reader :relative_paths

      protected

      ##
      # @private
      #
      def equality_fields
        super + [@path, @relative_paths]
      end

      private

      def validate_context_directory(context_directory)
        return if [:path, :parent].include?(context_directory)
        super
      end
    end

    ##
    # A spec for a source located in a git repository.
    #
    class Git < Base
      ##
      # Create a git spec.
      # This argument list is subject to change. Use
      # {Toys::SourceSpec.git} instead.
      #
      # @private
      #
      def initialize(remote, path, commit, update, context_directory, source_name)
        @remote = remote
        @path = path
        @commit = commit
        @update = update
        super(context_directory, source_name)
      end

      ##
      # The git repo URL, or `nil` to inherit it from the source doing the
      # loading.
      #
      # @return [String,nil]
      #
      attr_reader :remote

      ##
      # The path within the repo, or `nil` for the root of the repo.
      #
      # @return [String,nil]
      #
      attr_reader :path

      ##
      # The git ref, or `nil` to inherit it from the source doing the loading
      # or fall back to `"HEAD"`.
      #
      # @return [String,nil]
      #
      attr_reader :commit

      ##
      # Whether, and when, to force-fetch from the remote.
      #
      # @return [boolean,Integer]
      #
      attr_reader :update

      protected

      ##
      # @private
      #
      def equality_fields
        super + [@remote, @path, @commit, @update]
      end
    end

    ##
    # A spec for a source located in a gem.
    #
    # Beware that within the {Toys::SourceSpec} namespace, the name `Gem`
    # resolves to this class rather than to Ruby's `::Gem`. Prefix references
    # to the latter with `::`, as the project's style rules already require.
    #
    class Gem < Base
      ##
      # Create a gem spec.
      # This argument list is subject to change. Use
      # {Toys::SourceSpec.gem} instead.
      #
      # @private
      #
      def initialize(name, version, path, toys_dir, context_directory, source_name)
        @name = name
        @version = Array(version).dup.freeze
        @path = path
        @toys_dir = toys_dir
        super(context_directory, source_name)
      end

      ##
      # The gem name.
      #
      # @return [String]
      #
      attr_reader :name

      ##
      # The version requirements. Always an array, which is empty if any
      # version is allowed.
      #
      # @return [Array<String>]
      #
      attr_reader :version

      ##
      # The path from the gem's toys directory, or `nil` for the entire toys
      # directory.
      #
      # @return [String,nil]
      #
      attr_reader :path

      ##
      # The name of the gem's toys directory, or `nil` to use the default.
      #
      # @return [String,nil]
      #
      attr_reader :toys_dir

      protected

      ##
      # @private
      #
      def equality_fields
        super + [@name, @version, @path, @toys_dir]
      end
    end

    ##
    # A spec for a source given as a block of DSL code.
    #
    class Block < Base
      ##
      # Create a block spec.
      # This argument list is subject to change. Use
      # {Toys::SourceSpec.block} instead.
      #
      # @private
      #
      def initialize(block, context_directory, source_name)
        @block = block
        super(context_directory, source_name)
      end

      ##
      # The source block, to be executed in the context of the tool DSL
      # {Toys::DSL::Tool}.
      #
      # @return [Proc]
      #
      attr_reader :block

      protected

      ##
      # @private
      #
      def equality_fields
        super + [@block]
      end
    end

    ##
    # An empty SourceSpec
    # @return [Toys::SourceSpec::Base]
    #
    EMPTY = block {}.freeze # rubocop:disable Lint/EmptyBlock
  end
end
