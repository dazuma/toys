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
require "toys/utils/terminal"

module Toys
  module Middleware
    ##
    # A middleware that displays a version string for the root tool if the
    # `--version` flag is given.
    #
    class ShowRootVersion < Base
      ##
      # Default version flags
      # @return [Array<String>]
      #
      DEFAULT_VERSION_FLAGS = ["--version"].freeze

      ##
      # Default description for the version flags
      # @return [String]
      #
      DEFAULT_VERSION_FLAG_DESC = "Display the version".freeze

      ##
      # Create a ShowVersion middleware
      #
      # @param [String] version_string The string that should be displayed.
      # @param [Array<String>] version_flags A list of flags that should
      #     trigger displaying the version. Default is
      #     {DEFAULT_VERSION_FLAGS}.
      # @param [IO] stream Output stream to write to. Default is stdout.
      #
      def initialize(version_string: nil,
                     version_flags: DEFAULT_VERSION_FLAGS,
                     version_flag_desc: DEFAULT_VERSION_FLAG_DESC,
                     stream: $stdout)
        @version_string = version_string
        @version_flags = version_flags
        @version_flag_desc = version_flag_desc
        @terminal = Utils::Terminal.new(output: stream)
      end

      ##
      # Adds the version flag if requested.
      #
      def config(tool_definition, _loader)
        if @version_string && tool_definition.root?
          tool_definition.add_flag(:_show_version, @version_flags,
                                   report_collisions: false, desc: @version_flag_desc)
        end
        yield
      end

      ##
      # This middleware displays the version.
      #
      def run(tool)
        if tool[:_show_version]
          @terminal.puts(@version_string)
        else
          yield
        end
      end
    end
  end
end
