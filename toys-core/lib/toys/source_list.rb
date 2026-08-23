# frozen_string_literal: true

module Toys
  ##
  # An ordered collection of root sources for the Loader, held as unresolved
  # {Toys::SourceSpec} objects. Use this class to build a list of sources, and
  # then pass it to the Loader constructor.
  #
  # Each spec added to the list occupies its own priority level, and resolves
  # to a single root source. This is an invariant the Loader relies on.
  #
  # A source list resolves nothing. The specs it holds describe sources; the
  # Loader turns them into {Toys::SourceInfo} objects when it first needs
  # them.
  #
  # Not thread-safe. Callers should ensure that access is single-threaded or
  # synchronized.
  #
  class SourceList
    ##
    # Create an empty source list.
    #
    def initialize
      @sources = []
      @max_priority = @min_priority = 0
    end

    ##
    # Initialize a duplicate
    # @private
    #
    def initialize_copy(original)
      super
      @sources = @sources.dup
    end

    ##
    # Determines whether the list is empty.
    #
    # @return [boolean]
    #
    def empty?
      @sources.empty?
    end

    ##
    # Returns the size of the list.
    #
    # @return [Integer]
    #
    def size
      @sources.size
    end

    ##
    # Iterate over the source specs and their assigned priorities, in the
    # order in which they were added.
    #
    # @yield [Toys::SourceSpec::Base, Integer]
    # @return [self] if a block is given.
    # @return [Enumerator] if no block is given.
    #
    def each_with_priority(&block)
      return to_enum(:each_with_priority) unless block
      @sources.each(&block)
      self
    end

    ##
    # Add a source spec to the list, assigning it the next priority.
    #
    # @param spec [Toys::SourceSpec::Base] The source spec to add.
    # @param high_priority [boolean] If true, add this source at the top of the
    #     priority list. Defaults to false, indicating the new source should be
    #     at the bottom of the priority list.
    #
    # @return [self]
    # @raise [ArgumentError] if the given object is not a source spec.
    #
    def add(spec, high_priority: false)
      raise ::ArgumentError, "Illegal source spec: #{spec.inspect}" unless spec.is_a?(SourceSpec::Base)
      priority = high_priority ? @max_priority + 1 : @min_priority - 1
      @sources << [spec, priority]
      @max_priority = priority if priority > @max_priority
      @min_priority = priority if priority < @min_priority
      self
    end
  end
end
