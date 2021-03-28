# frozen_string_literal: true

require "rbconfig"

module Toys
  ##
  # Compatibility wrappers for older Ruby versions.
  # @private
  #
  module Compat
    parts = ::RUBY_VERSION.split(".")
    ruby_version = parts[0].to_i * 10000 + parts[1].to_i * 100 + parts[2].to_i

    # @private
    def self.jruby?
      ::RUBY_PLATFORM == "java"
    end

    # @private
    def self.windows?
      ::RbConfig::CONFIG["host_os"] =~ /mswin|msys|mingw|cygwin|bccwin|wince|emc/
    end

    # @private
    def self.allow_fork?
      !jruby? && !windows?
    end

    # @private
    def self.supports_suggestions?
      unless defined?(@supports_suggestions)
        begin
          require "did_you_mean"
        rescue ::LoadError
          require "rubygems"
          begin
            require "did_you_mean"
          rescue ::LoadError
            # Oh well, it's not available
          end
        end
        @supports_suggestions = defined?(::DidYouMean::SpellChecker)
      end
      @supports_suggestions
    end

    # @private
    def self.suggestions(word, list)
      if supports_suggestions?
        ::DidYouMean::SpellChecker.new(dictionary: list).correct(word)
      else
        []
      end
    end

    # The :base argument to Dir.glob requires Ruby 2.5 or later.
    if ruby_version >= 20500
      # @private
      def self.glob_in_dir(glob, dir)
        ::Dir.glob(glob, base: dir)
      end
    else
      # @private
      def self.glob_in_dir(glob, dir)
        ::Dir.chdir(dir) { ::Dir.glob(glob) }
      end
    end

    # Due to a bug in Ruby < 2.7, passing an empty **kwargs splat to
    # initialize will fail if there are no formal keyword args.
    if ruby_version >= 20700
      # @private
      def self.instantiate(klass, args, kwargs, block)
        klass.new(*args, **kwargs, &block)
      end
    else
      # @private
      def self.instantiate(klass, args, kwargs, block)
        formals = klass.instance_method(:initialize).parameters
        if kwargs.empty? && formals.all? { |arg| arg.first != :key && arg.first != :keyrest }
          klass.new(*args, &block)
        else
          klass.new(*args, **kwargs, &block)
        end
      end
    end
  end
end
