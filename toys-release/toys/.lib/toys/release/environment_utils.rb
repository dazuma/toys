# frozen_string_literal: true

module Toys
  module Release
    ##
    # An error raised by the release system
    #
    class ReleaseError < ::StandardError
      ##
      # Create a ReleaseError
      # @private
      #
      def initialize(message, more_messages)
        super(message)
        @more_messages = more_messages
      end

      ##
      # @return [Array<String>] Any secondary error messages
      #
      attr_reader :more_messages

      ##
      # @return [Array<String>] All messages including the primary and secondary
      #
      def all_messages
        [message] + more_messages
      end
    end

    ##
    # Utilities for running release scripts
    #
    class EnvironmentUtils
      ##
      # Create script utilities
      #
      def initialize(tool_context,
                     in_github_action: nil,
                     on_error_option: nil)
        @in_github_action = !::ENV["GITHUB_ACTIONS"].nil? if in_github_action.nil?
        @on_error_option = on_error_option || :exit
        @tool_context = tool_context
        @logger = tool_context.logger
        @error_list = nil
      end

      ##
      # @return [Toys::Context] The Toys tool context
      #
      attr_reader :tool_context

      ##
      # @return [Logger] The current Toys logger
      #
      attr_reader :logger

      ##
      # @return [:nothing,:raise,:exit] What to do on error
      #
      attr_reader :on_error_option

      ##
      # @return [boolean] Whether we are running in a GitHub action
      #
      def in_github_action?
        @in_github_action
      end

      ##
      # @return [String] Absolute path to the context directory
      #
      def context_directory
        tool_context.context_directory
      end

      ##
      # @return [String] Absolute path to the repo root directory
      #
      def repo_root_directory
        @repo_root_directory ||= capture(["git", "rev-parse", "--show-toplevel"], chdir: context_directory).strip
      end

      ##
      # Log a message at INFO level
      #
      # @param message [String] Message to log
      #
      def log(message)
        logger.info(message)
      end

      ##
      # Report a fatal error.
      #
      # @param message [String] Message to report
      # @param more_messages [Array<String>] Additional secondary messages
      #
      def error(message, *more_messages)
        if @error_list
          @error_list << message
          more_messages.each { |msg| @error_list << msg }
          return
        end
        if in_github_action? && !::ENV["TOYS_RELEASER_TESTING"]
          loc = caller_locations(1).first
          puts("::error file=#{loc.path},line=#{loc.lineno}::#{message}")
        else
          tool_context.puts(message, :red, :bold)
        end
        more_messages.each { |m| tool_context.puts(m, :red) }
        case on_error_option
        when :raise
          raise ReleaseError.new(message, more_messages)
        when :exit
          sleep(1) if in_github_action?
          tool_context.exit(1)
        end
      end

      ##
      # Accumulate any errors within the block. If any were present, then
      # emit them all at once, prefaced with the given main message.
      #
      # @param main_message [String,nil] An initial message to emit if there are
      #     errors. Omit if nil.
      #
      def accumulate_errors(main_message = nil)
        previous_list = @error_list
        @error_list = current_list = []
        result =
          begin
            yield
          ensure
            @error_list = previous_list
          end
        unless current_list.empty?
          current_list.unshift(main_message) if main_message
          error(*current_list)
        end
        result
      end

      ##
      # Accumulate any errors within the block and return the messages instead
      # of raising an exception or exiting. If no errors happened, returns the
      # empty array.
      #
      # @param errors [Array<String>,nil] If an array, append any errors to it
      #     in place, otherwise execute the block and let errors bubble through.
      # @return [Object] The block's result if success
      # @return [nil] if errors happened
      #
      def capture_errors(errors = nil, &block)
        return yield unless errors
        previous_option = on_error_option
        @on_error_option = :raise
        accumulate_errors(&block)
      rescue ReleaseError => e
        errors.concat(e.all_messages)
        nil
      ensure
        @on_error_option = previous_option
      end

      ##
      # Report a recoverable warning.
      #
      # @param message [String] Message to report
      # @param more_messages [Array<String>] Additional secondary messages
      #
      def warning(message, *more_messages)
        if in_github_action? && !::ENV["TOYS_RELEASER_TESTING"]
          loc = caller_locations(1).first
          puts("::warning file=#{loc.path},line=#{loc.lineno}::#{message}")
        else
          tool_context.puts(message, :yellow, :bold)
        end
        more_messages.each { |m| tool_context.puts(m, :yellow) }
      end

      ##
      # Run an external command.
      #
      # @param cmd [Array<String>] The command
      # @param opts [Hash] Extra options
      # @return [Toys::Utils::Exec::Result]
      #
      def exec(cmd, **opts, &block)
        modify_exec_opts(opts, cmd)
        tool_context.exec(cmd, **opts, &block)
      end

      ##
      # Run an external command and return its output.
      #
      # @param cmd [Array<String>] The command
      # @param opts [Hash] Extra options
      # @return [String] The output
      #
      def capture(cmd, **opts, &block)
        modify_exec_opts(opts, cmd)
        tool_context.capture(cmd, **opts, &block)
      end

      ##
      # Run an external Ruby script.
      #
      # @param code [String] The Ruby code
      # @param opts [Hash] Extra options
      # @return [Toys::Utils::Exec::Result]
      #
      def ruby(code, **opts, &block)
        opts[:in] = [:string, code]
        modify_exec_opts(opts, "ruby")
        tool_context.ruby([], **opts, &block)
      end

      ##
      # Run an external Ruby script and return its output.
      #
      # @param code [String] The Ruby code
      # @param opts [Hash] Extra options
      # @return [String] The output
      #
      def capture_ruby(code, **opts, &block)
        opts[:in] = [:string, code]
        modify_exec_opts(opts, "ruby")
        tool_context.capture_ruby([], **opts, &block)
      end

      ##
      # Run an external toys tool.
      #
      # @param cmd [Array<String>] The tool and its parameters
      # @param opts [Hash] Extra options
      # @return [Toys::Utils::Exec::Result]
      #
      def exec_separate_tool(cmd, **opts, &block)
        modify_exec_opts(opts, cmd)
        tool_context.exec_separate_tool(cmd, **opts, &block)
      end

      ##
      # Returns the URL for the current GitHub Actions workflow run.
      #
      # @return [String] Current workflow run URL
      # @return [nil] If not called from within a workflow run
      #
      def current_workflow_run_url
        return nil unless (server_url = ::ENV["GITHUB_SERVER_URL"])
        return nil unless (repo = ::ENV["GITHUB_REPOSITORY"])
        return nil unless (run_id = ::ENV["GITHUB_RUN_ID"])
        "#{server_url}/#{repo}/actions/runs/#{run_id}"
      end

      ##
      # Returns the SHA corresponding to an empty tree. This can be used as the
      # diff base for the initial commit. We compute this with an explicit git
      # call (but cache it) instead of hard-coding it, so we remain compatible
      # with both SHA-1 and SHA-256 repositories.
      #
      # @return [String] the SHA of the empty tree
      #
      def empty_tree_sha
        @empty_tree_sha ||= capture(["git", "hash-object", "-t", "tree", "--stdin"], e: true, in: :null).strip
      end

      private

      def modify_exec_opts(opts, cmd)
        if opts.delete(:e) || opts.delete(:exit_on_nonzero_status)
          opts[:result_callback] ||=
            proc do |r|
              error("Command failed with exit code #{r.exit_code}: #{cmd.inspect}") if r.error?
            end
        end
      end
    end
  end
end
