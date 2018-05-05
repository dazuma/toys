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

module Toys
  module Middleware
    ##
    # This middleware sets default description fields for tools that do not
    # have them set otherwise. You can set separate descriptions for tools,
    # groups, and the root.
    #
    class SetDefaultDescriptions < Base
      ##
      # The default description for tools.
      # @return [String]
      #
      DEFAULT_TOOL_DESC = "(No description available)".freeze

      ##
      # The default description for groups.
      # @return [String]
      #
      DEFAULT_GROUP_DESC = "(A group of commands)".freeze

      ##
      # The default description for the root tool.
      # @return [String]
      #
      DEFAULT_ROOT_DESC =
        "This is a toys-based command line tool, built using the toys-core" \
        " gem. See https://www.rubydoc.info/gems/toys-core for more info." \
        " To replace this message, configure the SetDefaultDescriptions" \
        " middleware.".freeze

      ##
      # Create a SetDefaultDescriptions middleware given default descriptions.
      #
      # @param [String] default_tool_desc The default short description for
      #     tools with an eecutor. Defaults to {DEFAULT_TOOL_DESC}.
      # @param [String,nil] default_tool_long_desc The default long description
      #     for tools with an eecutor. If `nil` (the default), falls back to
      #     the value of the `default_tool_desc` parameter.
      # @param [String] default_group_desc The default short description for
      #     tools with no eecutor. Defaults to {DEFAULT_GROUP_DESC}.
      # @param [String,nil] default_group_long_desc The default long
      #     description for tools with no eecutor. If `nil` (the default),
      #     falls back to the value of the `default_group_desc` parameter.
      # @param [String] default_root_desc The default long description for the
      #     root tool. Defaults to {DEFAULT_ROOT_DESC}.
      #
      def initialize(default_tool_desc: DEFAULT_TOOL_DESC,
                     default_tool_long_desc: nil,
                     default_group_desc: DEFAULT_GROUP_DESC,
                     default_group_long_desc: nil,
                     default_root_desc: DEFAULT_ROOT_DESC)
        @default_tool_desc = default_tool_desc
        @default_tool_long_desc = default_tool_long_desc
        @default_group_desc = default_group_desc
        @default_group_long_desc = default_group_long_desc
        @default_root_desc = default_root_desc
      end

      ##
      # Add default description text to tools.
      #
      def config(tool)
        if tool.root?
          config_root_desc(tool)
        elsif tool.includes_executor?
          config_tool_desc(tool)
        else
          config_group_desc(tool)
        end
        yield
      end

      private

      def config_root_desc(tool)
        if @default_root_desc && tool.effective_long_desc.empty?
          tool.long_desc = @default_root_desc
        end
      end

      def config_tool_desc(tool)
        if @default_tool_long_desc && tool.effective_long_desc.empty?
          tool.long_desc = @default_tool_long_desc
        end
        if @default_tool_desc && tool.effective_desc.empty?
          tool.desc = @default_tool_desc
        end
      end

      def config_group_desc(tool)
        if @default_group_long_desc && tool.effective_long_desc.empty?
          tool.long_desc = @default_group_long_desc
        end
        if @default_group_desc && tool.effective_desc.empty?
          tool.desc = @default_group_desc
        end
      end
    end
  end
end
