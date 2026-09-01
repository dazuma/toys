# frozen_string_literal: true

module Toys
  class SourceInfo
    ##
    # An origin describes where a source's content came from: the local file
    # system, a git repository, a Ruby gem, or a block of code.
    #
    # An origin is determined when a source spec is resolved, and it does not
    # change as a loader descends into child sources. Every {Toys::SourceInfo}
    # created by descending from another, whether by walking a directory or by
    # entering a block or a subclass, shares its parent's origin object. A
    # child created by resolving a new source spec gets its own origin instead.
    #
    # An origin is thus fixed information about a resolution: which git remote
    # and commit, or which gem and version, the content came from. Where a
    # particular source sits *within* that content is tracked by the
    # {Toys::SourceInfo} rather than by the origin, and is what makes
    # {Toys::SourceInfo#source_path} differ from one source to the next while
    # the origin stays the same.
    #
    # This is distinct from {Toys::SourceInfo#source_type}, which says what a
    # source *is* — a file, a directory, a block, or a subclass — rather than
    # where it came from. The two vary independently: a git origin can yield
    # either a file or a directory, and a block within a file loaded from git
    # keeps that git origin.
    #
    module Origin
      class << self
        ##
        # Combine a relative base path, which may be empty, with a relative
        # path, and return the result as a relative path.
        #
        # @private This interface is internal and subject to change without warning.
        #
        def join_relative(base, relative)
          if relative == "." || relative.to_s.empty?
            base
          elsif base == "." || base.to_s.empty?
            relative
          else
            ::File.join(base, relative)
          end
        end
      end

      ##
      # The base class of an origin, holding the path that the source spec
      # resolved to.
      #
      # Do not instantiate this class directly. A {Toys::SourceInfo} creates
      # the appropriate subclass when it resolves a source spec.
      #
      class Base
        ##
        # Create an origin.
        #
        # @private This interface is internal and subject to change without warning.
        #
        def initialize(initial_path)
          @initial_path = initial_path
        end

        ##
        # The file system path that the source spec resolved to. A source's
        # own path is this path, plus its position below it.
        #
        # @private This interface is internal and subject to change without warning.
        #
        attr_reader :initial_path

        ##
        # Return the given relative path joined atop the initial path.
        #
        # @private This interface is internal and subject to change without warning.
        #
        def joined_path(relative_path)
          return nil if initial_path.nil?
          return initial_path if relative_path == "." || relative_path.to_s.empty?
          ::File.expand_path(::File.join(initial_path, relative_path))
        end

        ##
        # Describe a source at the given path relative to {#initial_path}, for
        # use as a default source name.
        #
        # @private This interface is internal and subject to change without warning.
        #
        def describe(relative_path)
          raise ::NotImplementedError,
                "#{self.class} does not describe a source: #{relative_path.inspect}"
        end
      end

      ##
      # The origin of a source read from the local file system.
      #
      class Local < Base
        ##
        # @private This interface is internal and subject to change without warning.
        #
        def describe(relative_path)
          joined_path(relative_path)
        end
      end

      ##
      # The origin of a source read from a git repository.
      #
      class Git < Base
        ##
        # Create a git origin.
        #
        # @private This interface is internal and subject to change without warning.
        #
        def initialize(initial_path, remote, commit, path)
          super(initial_path)
          @remote = remote
          @commit = commit
          @path = path
        end

        ##
        # The git remote that the content was fetched from.
        #
        # @return [String]
        #
        attr_reader :remote

        ##
        # The git commit that the content was read at. This is the ref that was
        # requested, which could be a SHA, a tag, or a branch name.
        #
        # @return [String]
        #
        attr_reader :commit

        ##
        # The path within the repository that was read. This is the path of the
        # resolved source itself, and does not descend with child sources. It
        # could be the empty string, meaning the root of the repository.
        #
        # @return [String]
        #
        attr_reader :path

        ##
        # @private This interface is internal and subject to change without warning.
        #
        def describe(relative_path)
          full_path = Origin.join_relative(path, relative_path)
          "git(remote=#{remote} path=#{full_path} commit=#{commit})"
        end
      end

      ##
      # The origin of a source read from a Ruby gem.
      #
      # Note that within the {Toys::SourceInfo::Origin} module, the name `Gem`
      # resolves to this class rather than to Ruby's `::Gem`. Prefix references
      # to the latter with `::`.
      #
      class Gem < Base
        ##
        # Create a gem origin.
        #
        # @private This interface is internal and subject to change without warning.
        #
        def initialize(initial_path, name, version, path)
          super(initial_path)
          @name = name
          @version = version
          @path = path
        end

        ##
        # The name of the gem that the content was read from.
        #
        # @return [String]
        #
        attr_reader :name

        ##
        # The version of the gem that was activated.
        #
        # @return [::Gem::Version]
        #
        attr_reader :version

        ##
        # The path within the gem that was read, including the gem's toys root
        # directory. This is the path of the resolved source itself, and does
        # not descend with child sources.
        #
        # @return [String]
        #
        attr_reader :path

        ##
        # @private This interface is internal and subject to change without warning.
        #
        def describe(relative_path)
          full_path = Origin.join_relative(path, relative_path)
          "gem(name=#{name} version=#{version} path=#{full_path})"
        end
      end

      ##
      # The origin of a source that is a block of code passed directly to a
      # CLI, and so came from nowhere on the file system.
      #
      # A block origin never describes a source, because a source with this
      # origin always has a {Toys::SourceInfo#source_type} of `:proc`, which
      # takes its name from the block itself.
      #
      class Block < Base
        ##
        # Create a block origin.
        #
        # @private This interface is internal and subject to change without warning.
        #
        def initialize
          super(nil)
        end
      end
    end
  end
end
