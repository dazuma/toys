# Copyright 2018 Daniel Azuma
#
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# * Redistributions of source code must retain the above copyright notice,
#   this list of conditions and the following disclaimer.
# * Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
# * Neither the name of the copyright holder, nor the names of any other
#   contributors to this software, may be used to endorse or promote products
#   derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
;

require "toys/middleware/base"
require "toys/utils/line_output"

module Toys
  module Middleware
    ##
    # A middleware that displays a version string for certain tools if the
    # `--version` flag is given. You can specify which tools respond to
    # this flag, and the string that will be displayed.
    #
    class ShowVersion < Base
      ##
      # Default version flags
      # @return [Array<String>]
      #
      DEFAULT_VERSION_FLAGS = ["--version"].freeze

      ##
      # Return a simple version displayer that returns the given string for
      # the root tool.
      #
      # @return [Proc]
      #
      def self.root_version_displayer(version)
        proc { |tool| tool.root? ? version : false }
      end

      ##
      # Create a ShowVersion middleware
      #
      # @param [Proc] version_displayer A proc that takes a tool and returns
      #     either the version string that should be displayed, or a falsy
      #     value to indicate the tool should not have a `--version` flag.
      #     Defaults to a "null" displayer that returns false for all tools.
      # @param [Array<String>] version_flags A list of flags that should
      #     trigger displaying the version. Default is
      #     {DEFAULT_VERSION_FLAGS}.
      # @param [IO] stream Output stream to write to. Default is stdout.
      #
      def initialize(version_displayer: nil,
                     version_flags: DEFAULT_VERSION_FLAGS,
                     stream: $stdout)
        @version_displayer = version_displayer || proc { |_| false }
        @version_flags = version_flags
        @output = Utils::LineOutput.new(stream)
      end

      ##
      # Adds the version flag if requested.
      #
      def config(tool)
        version = @version_displayer.call(tool)
        if version
          tool.add_flag(:_show_version, *@version_flags,
                        desc: "Show version",
                        handler: ->(_val, _prev) { version },
                        only_unique: true)
        end
        yield
      end

      ##
      # This middleware displays the version.
      #
      def execute(context)
        if context[:_show_version]
          @output.puts context[:_show_version]
        else
          yield
        end
      end
    end
  end
end
