# frozen_string_literal: true

require "toys/utils/exec"

module Toys
  module Utils
    ##
    # A class that invokes an external pager.
    #
    # @example Using a pager for regular output
    #
    #   Toys::Utils::Pager.start do |io|
    #     io.puts "A long string\n"
    #   end
    #
    # @example Piping output from a command
    #
    #   exec_service = Toys::Utils::Exec.new
    #   Toys::Utils::Pager.start(exec_service: exec_service) do |io|
    #     exec_service.exec(["/bin/ls", "-alF"], out: io)
    #   end
    #
    class Pager
      ##
      # Creates a new pager.
      #
      # @param command [String,Array<String>,boolean] The command to use to
      #     invoke the pager. May be specified as a string to be passed to the
      #     shell, an array of strings representing a posix command, the value
      #     `true` to use the default (normally `less -FIRX`), or the value
      #     `false` to disable the pager and write directly to the output
      #     stream. Default is `true`.
      # @param exec_service [Toys::Utils::Exec] The service to use for
      #     executing commands, or `nil` (the default) to use a default.
      # @param fallback_io [IO] An IO-like object to write to if the pager is
      #     disabled. Defaults to `$stdout`.
      # @param rescue_broken_pipes [boolean] If `true` (the default), broken
      #     pipes are silently rescued. This prevents the exception from
      #     propagating out if the pager is interrupted. Set this parameter to
      #     `false` to disable this behavior.
      #
      def initialize(command: true, exec_service: nil, fallback_io: nil,
                     rescue_broken_pipes: true)
        @command = command == true ? Pager.default_command : command
        @command ||= nil
        @exec_service = exec_service || Pager.default_exec_service
        @fallback_io = fallback_io || $stdout
        @rescue_broken_pipes = rescue_broken_pipes
      end

      ##
      # Runs the pager. Takes a block and yields an IO-like object that passes
      # text to the pager. Can be called multiple times on the same pager.
      #
      # @yieldparam io [IO] An object that can be written to, to pass data to
      #     the pager.
      # @return [Integer] The exit code of the pager process.
      #
      # @example
      #
      #   pager = Toys::Utils::Pager.new
      #   pager.start do |io|
      #     io.puts "A long string\n"
      #   end
      #
      def start
        if @command
          result = @exec_service.exec(@command, in: :controller) do |controller|
            begin
              yield controller.in if controller.pid
            rescue ::Errno::EPIPE => e
              raise e unless @rescue_broken_pipes
            end
          end
          return result.exit_code unless result.failed?
        end
        yield @fallback_io
        0
      end

      ##
      # The command for running the pager process. May be specified as a string
      # to be passed to the shell, an array of strings representing a posix
      # command, or `nil` to disable the pager and write directly to an output
      # stream.
      #
      # @return [String,Array<String>,nil]
      #
      attr_accessor :command

      ##
      # The IO stream used if the pager is disabled or could not be executed.
      #
      # @return [IO]
      #
      attr_accessor :fallback_io

      class << self
        ##
        # A convenience method that creates a pager and runs it once by calling
        # {Pager#start}.
        #
        # @param command [String,Array<String>,boolean] The command to use to
        #     invoke the pager. May be specified as a string to be passed to the
        #     shell, an array of strings representing a posix command, the value
        #     `true` to use the default (normally `less -FIRX`), or the value
        #     `false` to disable the pager and write directly to the output
        #     stream. Default is `true`.
        # @param exec_service [Toys::Utils::Exec] The service to use for
        #     executing commands, or `nil` (the default) to use a default.
        # @param fallback_io [IO] An IO-like object to write to if the pager is
        #     disabled. Defaults to `$stdout`.
        # @param rescue_broken_pipes [boolean] If `true` (the default), broken
        #     pipes are silently rescued. This prevents the exception from
        #     propagating out if the pager is interrupted. Set this parameter to
        #     `false` to disable this behavior.
        # @return [Integer] The exit code of the pager process.
        #
        # @example
        #
        #   Toys::Utils::Pager.start do |io|
        #     io.puts "A long string\n"
        #   end
        #
        def start(command: true,
                  exec_service: nil,
                  fallback_io: nil,
                  rescue_broken_pipes: true,
                  &block)
          pager = new(command: command, exec_service: exec_service, fallback_io: fallback_io,
                      rescue_broken_pipes: rescue_broken_pipes)
          pager.start(&block)
        end

        ##
        # @private
        #
        def default_command
          unless defined? @default_command
            @default_command = ::ENV["PAGER"]
            unless @default_command
              path = `which less`.strip
              @default_command = [path, "-FIRX"] unless path.empty?
            end
          end
          @default_command
        end

        ##
        # @private
        #
        def default_exec_service
          @default_exec_service ||= Exec.new
        end
      end
    end
  end
end
