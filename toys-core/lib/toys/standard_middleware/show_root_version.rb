# frozen_string_literal: true

module Toys
  module StandardMiddleware
    ##
    # A middleware that displays a version string for the root tool if the
    # `--version` flag is given.
    #
    class ShowRootVersion
      ##
      # Default version flags
      # @return [Array<String>]
      #
      DEFAULT_VERSION_FLAGS = ["--version"].freeze

      ##
      # Default description for the version flags
      # @return [String]
      #
      DEFAULT_VERSION_FLAG_DESC = "Display the version"

      ##
      # Key set when the version flag is present
      # @return [Object]
      #
      SHOW_VERSION_KEY = Object.new.freeze

      ##
      # Create a ShowVersion middleware
      #
      # @param version_string [String] The string that should be displayed.
      # @param version_flags [Array<String>] A list of flags that should
      #     trigger displaying the version. Default is
      #     {DEFAULT_VERSION_FLAGS}.
      # @param stream [IO] Output stream to write to. Default is stdout.
      #
      def initialize(version_string: nil,
                     version_flags: DEFAULT_VERSION_FLAGS,
                     version_flag_desc: DEFAULT_VERSION_FLAG_DESC,
                     stream: $stdout)
        @version_string = version_string
        @version_flags = version_flags
        @version_flag_desc = version_flag_desc
        @output = stream
      end

      ##
      # Adds the version flag if requested.
      # @private
      #
      def config(tool, _loader)
        if @version_string && tool.root?
          tool.add_flag(SHOW_VERSION_KEY, @version_flags,
                        report_collisions: false, desc: @version_flag_desc)
        end
        yield
      end

      ##
      # This middleware displays the version.
      # @private
      #
      def run(context)
        if context[SHOW_VERSION_KEY]
          @output.puts(@version_string)
        else
          yield
        end
      end
    end
  end
end
