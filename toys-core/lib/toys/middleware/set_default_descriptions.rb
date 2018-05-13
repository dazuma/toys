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
      DEFAULT_TOOL_DESC = "(No tool description available)".freeze

      ##
      # The default description for groups.
      # @return [String]
      #
      DEFAULT_GROUP_DESC = "(A group of tools)".freeze

      ##
      # The default description for the root tool.
      # @return [String]
      #
      DEFAULT_ROOT_DESC = "Command line tool built using the toys-core gem.".freeze

      ##
      # The default long description for the root tool.
      # @return [Toys::Utils::WrappableString]
      #
      DEFAULT_ROOT_LONG_DESC =
        Utils::WrappableString.new(
          "This command line tool was built using the toys-core gem." \
          " See https://www.rubydoc.info/gems/toys-core for more info." \
          " To replace this message, configure the SetDefaultDescriptions" \
          " middleware."
        )

      ##
      # The default description for flags.
      # @return [String]
      #
      DEFAULT_FLAG_DESC = "(No flag description available)".freeze

      ##
      # The default description for required args.
      # @return [String]
      #
      DEFAULT_REQUIRED_ARG_DESC = "(Required argument - no description available)".freeze

      ##
      # The default description for optional args.
      # @return [String]
      #
      DEFAULT_OPTIONAL_ARG_DESC = "(Optional argument - no description available)".freeze

      ##
      # The default description for remaining args.
      # @return [String]
      #
      DEFAULT_REMAINING_ARG_DESC = "(Remaining arguments - no description available)".freeze

      ##
      # Create a SetDefaultDescriptions middleware given default descriptions.
      #
      # @param [String,nil] default_tool_desc The default short description for
      #     tools with an executor, or `nil` not to set one. Defaults to
      #     {DEFAULT_TOOL_DESC}.
      # @param [String,nil] default_tool_long_desc The default long description
      #     for tools with an executor, or `nil` not to set one. Defaults to
      #     `nil`.
      # @param [String,nil] default_group_desc The default short description
      #     for tools with no executor, or `nil` not to set one. Defaults to
      #     {DEFAULT_TOOL_DESC}.
      # @param [String,nil] default_group_long_desc The default long
      #     description for tools with no executor, or `nil` not to set one.
      #     Defaults to `nil`.
      # @param [String,nil] default_root_desc The default short description for
      #     the root tool, or `nil` not to set one. Defaults to
      #     {DEFAULT_ROOT_DESC}.
      # @param [String,nil] default_root_long_desc The default long description
      #     for the root tool, or `nil` not to set one. Defaults to
      #     {DEFAULT_ROOT_LONG_DESC}.
      # @param [String,nil] default_flag_desc The default short description for
      #     flags, or `nil` not to set one. Defaults to {DEFAULT_FLAG_DESC}.
      # @param [String,nil] default_flag_long_desc The default long description
      #     for flags, or `nil` not to set one. Defaults to `nil`.
      # @param [String,nil] default_required_arg_desc The default short
      #     description for required args, or `nil` not to set one. Defaults to
      #     {DEFAULT_REQUIRED_ARG_DESC}.
      # @param [String,nil] default_required_arg_long_desc The default long
      #     description for required args, or `nil` not to set one. Defaults to
      #     `nil`.
      # @param [String,nil] default_optional_arg_desc The default short
      #     description for optional args, or `nil` not to set one. Defaults to
      #     {DEFAULT_OPTIONAL_ARG_DESC}.
      # @param [String,nil] default_optional_arg_long_desc The default long
      #     description for optional args, or `nil` not to set one. Defaults to
      #     `nil`.
      # @param [String,nil] default_remaining_arg_desc The default short
      #     description for remaining args, or `nil` not to set one. Defaults
      #     to {DEFAULT_REMAINING_ARG_DESC}.
      # @param [String,nil] default_remaining_arg_long_desc The default long
      #     description for remaining args, or `nil` not to set one. Defaults
      #     to `nil`.
      #
      def initialize(default_tool_desc: DEFAULT_TOOL_DESC,
                     default_tool_long_desc: nil,
                     default_group_desc: DEFAULT_GROUP_DESC,
                     default_group_long_desc: nil,
                     default_root_desc: DEFAULT_ROOT_DESC,
                     default_root_long_desc: DEFAULT_ROOT_LONG_DESC,
                     default_flag_desc: DEFAULT_FLAG_DESC,
                     default_flag_long_desc: nil,
                     default_required_arg_desc: DEFAULT_REQUIRED_ARG_DESC,
                     default_required_arg_long_desc: nil,
                     default_optional_arg_desc: DEFAULT_OPTIONAL_ARG_DESC,
                     default_optional_arg_long_desc: nil,
                     default_remaining_arg_desc: DEFAULT_REMAINING_ARG_DESC,
                     default_remaining_arg_long_desc: nil)
        @default_tool_desc = default_tool_desc
        @default_tool_long_desc = default_tool_long_desc
        @default_group_desc = default_group_desc
        @default_group_long_desc = default_group_long_desc
        @default_root_desc = default_root_desc
        @default_root_long_desc = default_root_long_desc
        @default_flag_desc = default_flag_desc
        @default_flag_long_desc = default_flag_long_desc
        @default_required_arg_desc = default_required_arg_desc
        @default_required_arg_long_desc = default_required_arg_long_desc
        @default_optional_arg_desc = default_optional_arg_desc
        @default_optional_arg_long_desc = default_optional_arg_long_desc
        @default_remaining_arg_desc = default_remaining_arg_desc
        @default_remaining_arg_long_desc = default_remaining_arg_long_desc
      end

      ##
      # Add default description text to tools.
      #
      def config(tool)
        if tool.root?
          config_descs(tool, @default_root_desc, @default_root_long_desc)
        elsif tool.includes_executor?
          config_descs(tool, @default_tool_desc, @default_tool_long_desc)
        else
          config_descs(tool, @default_group_desc, @default_group_long_desc)
        end
        tool.flag_definitions.each do |flag|
          config_descs(flag, @default_flag_desc, @default_flag_long_desc)
        end
        config_args(tool)
        yield
      end

      private

      def config_args(tool)
        tool.required_arg_definitions.each do |arg|
          config_descs(arg, @default_required_arg_desc, @default_required_arg_long_desc)
        end
        tool.optional_arg_definitions.each do |arg|
          config_descs(arg, @default_optional_arg_desc, @default_optional_arg_long_desc)
        end
        if tool.remaining_args_definition
          config_descs(tool.remaining_args_definition,
                       @default_remaining_arg_desc, @default_remaining_arg_long_desc)
        end
      end

      def config_descs(object, default_desc, default_long_desc)
        if default_desc && object.desc.empty?
          object.desc = default_desc
        end
        if default_long_desc && object.long_desc.empty?
          object.long_desc = default_long_desc
        end
      end
    end
  end
end
