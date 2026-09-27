# frozen_string_literal: true

module Toys
  ##
  # A warning reporter that supports throttling of repeated messages and
  # environment variable based silencing. Used in particular to display
  # deprecation warnings.
  #
  module Warnings
    ##
    # @return [Integer] The default value for {Warnings.max_count}.
    #
    DEFAULT_MAX_COUNT = 5

    ##
    # @return [String] The name of an environment variable that, when set to a
    #     non-empty value, suppresses warnings emitted by this module.
    #
    SUPPRESS_WARNINGS_ENV = "TOYS_SUPPRESS_WARNINGS"

    FURTHER_SUPPRESSED_MSG = "further warnings suppressed"
    private_constant :FURTHER_SUPPRESSED_MSG

    ENV_SUPPRESSION_MSG = "to suppress these warnings altogether, set #{SUPPRESS_WARNINGS_ENV} to a nonempty value"
    private_constant :ENV_SUPPRESSION_MSG

    @mutex = ::Mutex.new
    @max_count = DEFAULT_MAX_COUNT

    class << self
      ##
      # The maximum number of times a warning with the same identity will be
      # displayed before further instances are suppressed, or nil to keep
      # displaying each warning regardless of how many times it has repeated.
      # Defaults to {DEFAULT_MAX_COUNT}. Can be set using
      # {Toys::Warnings.max_count=}.
      #
      # @return [Integer,nil]
      #
      attr_reader :max_count

      ##
      # Set the maximum number of times a warning with the same identity will
      # be displayed before further instances are suppressed. Must be a
      # nonnegative integer, or nil to keep displaying each warning regardless
      # of how many times it has repeated. The value 0 suppresses warnings
      # unconditionally.
      #
      # @param value [Integer,nil] The new max_count value
      #
      def max_count=(value)
        @max_count = validate_max_count(value)
      end

      ##
      # Displays a warning message.
      #
      # You must pass an identifier object and a message string. The identifier
      # should identify "which" warning is being displayed, and is used to
      # count repeated warnings so they can be throttled after a certain number
      # of instances.
      #
      # Uses the Ruby `Kernel#warn` method, so it is affected by `$VERBOSE` and
      # the `-W0` flag. Does not currently support the `category:` argument to
      # `Kernel#warn` because it is not supported in Ruby 2.7, and in newer
      # Rubies, common values such as `category: :deprecated` default to silent,
      # whereas this method should not be silent unless explicitly requested.
      #
      # @param identifier [Object] An object that identifies the warning for
      #     counting purposes. Generally this should be a fixed small set of
      #     objects, preferably symbols, as each identifier seen is used as a
      #     hash key and never deleted.
      # @param message [String] The warning message
      # @param uplevel [Integer,nil] If given and set to a nonnegative Integer,
      #     the warning will be prepended with the caller frame, that many
      #     stack levels above the call site. If not given or set to nil, the
      #     caller is not included in the report.
      # @param max_count [Integer,nil,:default] The maximum number of times a
      #     warning with the same identity will be displayed before further
      #     instances are suppressed. Must be a nonnegative integer, or nil to
      #     keep displaying each warning regardless of how many times it has
      #     repeated. The value 0 suppresses warnings of this identifier
      #     unconditionally. The special value `:default` (which is used if the
      #     argument is not provided) falls back to {Toys::Warnings.max_count}.
      #
      # @return [Integer] The number of times this warning's identifier has
      #     happened, regardless of whether it was actually displayed.
      #
      def warn(identifier, message, uplevel: nil, max_count: :default)
        if max_count == :default
          max_count = @max_count
        else
          validate_max_count(max_count)
        end
        uplevel = validate_and_bump_uplevel(uplevel)
        count = next_count(identifier)
        message = annotate_message(message, count, max_count)
        if message && ::ENV[SUPPRESS_WARNINGS_ENV].to_s.empty?
          ::Kernel.warn(message, uplevel: uplevel)
        end
        count
      end

      ##
      # @private
      #
      # Reset warning counts.
      # Not a documented/supported interface. Used only to initialize things at
      # file load, and to reset things for testing.
      #
      # @return [void]
      #
      def reset_counts
        # Intentionally not synchronized. This should be called only at file
        # load and during testing, so we're not worried about concurrency.
        @warning_counts = ::Hash.new(0)
        nil
      end

      private

      def validate_max_count(value)
        return value if value.nil? || (value.is_a?(::Integer) && !value.negative?)
        raise ::ArgumentError, "max_count must be a nonnegative integer or nil"
      end

      def validate_and_bump_uplevel(value)
        return value if value.nil?
        if !value.is_a?(::Integer) || value.negative?
          raise ::ArgumentError, "uplevel should be nil or a nonnegative Integer"
        end
        value + 1
      end

      # Get the count for a warning with the given identifier
      def next_count(identifier)
        @mutex.synchronize { @warning_counts[identifier] += 1 }
      rescue ::ThreadError
        # Synchronize may fail if warn is called from a signal handler. In this
        # case, just increment without the mutex and accept the possible off by
        # one concurrency issues as minor.
        @warning_counts[identifier] += 1
      end

      # Returns the final message to display, or nil to suppress messages
      # because count is past the maximum.
      def annotate_message(message, count, max_count)
        return nil if max_count && count > max_count
        message = message.to_s.chomp
        additions = []
        additions << "count: #{count}" if count > 1
        additions << FURTHER_SUPPRESSED_MSG if max_count && count == max_count
        additions << ENV_SUPPRESSION_MSG if count == 1
        suffix = additions.join(", ")
        suffix.empty? ? message : "#{message} (#{suffix})"
      end
    end

    reset_counts
  end
end
