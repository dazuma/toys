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
    # This middleware sets default description fields for tools and command
    # line arguments and flags that do not have them set otherwise.
    #
    # You can modify the static descriptions for tools, namespaces, and the
    # root tool by passing parameters to this middleware. For finer control,
    # you can override methods to modify the description generation logic.
    #
    class SetDefaultDescriptions < Base
      ##
      # The default description for tools.
      # @return [String]
      #
      DEFAULT_TOOL_DESC = "(No tool description available)".freeze

      ##
      # The default description for namespaces.
      # @return [String]
      #
      DEFAULT_NAMESPACE_DESC = "(A namespace of tools)".freeze

      ##
      # The default description for the root tool.
      # @return [String]
      #
      DEFAULT_ROOT_DESC = "Command line tool built using the toys-core gem.".freeze

      ##
      # The default long description for the root tool.
      # @return [String]
      #
      DEFAULT_ROOT_LONG_DESC = [
        "This command line tool was built using the toys-core gem. See" \
          " https://www.rubydoc.info/gems/toys-core for more info.",
        "To replace this message, configure the SetDefaultDescriptions middleware."
      ].freeze

      ##
      # A mapping of names for acceptable types
      # @return [Hash]
      #
      ACCEPTABLE_NAMES = {
        nil => "string",
        ::String => "nonempty string",
        ::TrueClass => "boolean",
        ::FalseClass => "boolean",
        ::OptionParser::DecimalInteger => "decimal integer",
        ::OptionParser::OctalInteger => "octal integer",
        ::OptionParser::DecimalNumeric => "decimal numeric"
      }.freeze

      ##
      # Create a SetDefaultDescriptions middleware given default descriptions.
      #
      # @param [String,nil] default_tool_desc The default short description for
      #     runnable tools, or `nil` not to set one. Defaults to
      #     {DEFAULT_TOOL_DESC}.
      # @param [String,nil] default_tool_long_desc The default long description
      #     for runnable tools, or `nil` not to set one. Defaults to `nil`.
      # @param [String,nil] default_namespace_desc The default short
      #     description for non-runnable tools, or `nil` not to set one.
      #     Defaults to {DEFAULT_TOOL_DESC}.
      # @param [String,nil] default_namespace_long_desc The default long
      #     description for non-runnable tools, or `nil` not to set one.
      #     Defaults to `nil`.
      # @param [String,nil] default_root_desc The default short description for
      #     the root tool, or `nil` not to set one. Defaults to
      #     {DEFAULT_ROOT_DESC}.
      # @param [String,nil] default_root_long_desc The default long description
      #     for the root tool, or `nil` not to set one. Defaults to
      #     {DEFAULT_ROOT_LONG_DESC}.
      #
      def initialize(default_tool_desc: DEFAULT_TOOL_DESC,
                     default_tool_long_desc: nil,
                     default_namespace_desc: DEFAULT_NAMESPACE_DESC,
                     default_namespace_long_desc: nil,
                     default_root_desc: DEFAULT_ROOT_DESC,
                     default_root_long_desc: DEFAULT_ROOT_LONG_DESC)
        @default_tool_desc = default_tool_desc
        @default_tool_long_desc = default_tool_long_desc
        @default_namespace_desc = default_namespace_desc
        @default_namespace_long_desc = default_namespace_long_desc
        @default_root_desc = default_root_desc
        @default_root_long_desc = default_root_long_desc
      end

      ##
      # Add default description text to tools.
      #
      def config(tool, loader)
        data = {tool: tool, loader: loader}
        tool.flag_definitions.each do |flag|
          config_desc(flag, generate_flag_desc(flag, data), generate_flag_long_desc(flag, data))
        end
        tool.arg_definitions.each do |arg|
          config_desc(arg, generate_arg_desc(arg, data), generate_arg_long_desc(arg, data))
        end
        config_desc(tool, generate_tool_desc(tool, data), generate_tool_long_desc(tool, data))
        yield
      end

      protected

      ##
      # This method implements the logic for generating a tool description.
      # By default, it uses the parameters given to the middleware object.
      # Override this method to provide different logic.
      #
      # @param [Toys::Tool] tool The tool to document.
      # @param [Hash] data Additional data that might be useful. Currently,
      #     the {Toys::Loader} is passed with key `:loader`. Future versions
      #     of Toys may provide additional information.
      # @return [String,Array<String>,Toys::Utils::WrappableString,nil] The
      #     default description, or `nil` not to set a default. See
      #     {Toys::Tool#desc=} for info on the format.
      #
      def generate_tool_desc(tool, data)
        if tool.root?
          @default_root_desc
        elsif !tool.runnable? && data[:loader].has_subtools?(tool.full_name)
          @default_namespace_desc
        else
          @default_tool_desc
        end
      end

      ##
      # This method implements logic for generating a tool long description.
      # By default, it uses the parameters given to the middleware object.
      # Override this method to provide different logic.
      #
      # @param [Toys::Tool] tool The tool to document
      # @param [Hash] data Additional data that might be useful. Currently,
      #     the {Toys::Loader} is passed with key `:loader`. Future versions
      #     of Toys may provide additional information.
      # @return [Array<Toys::Utils::WrappableString,String,Array<String>>,nil]
      #     The default long description, or `nil` not to set a default. See
      #     {Toys::Tool#long_desc=} for info on the format.
      #
      def generate_tool_long_desc(tool, data)
        if tool.root?
          @default_root_long_desc
        elsif !tool.runnable? && data[:loader].has_subtools?(tool.full_name)
          @default_namespace_long_desc
        else
          @default_tool_long_desc
        end
      end

      ##
      # This method implements the logic for generating a flag description.
      # Override this method to provide different logic.
      #
      # @param [Toys::Tool::FlagDefinition] flag The flag to document
      # @param [Hash] data Additional data that might be useful. Currently,
      #     the {Toys::Tool} is passed with key `:tool`. Future versions of
      #     Toys may provide additional information.
      # @return [String,Array<String>,Toys::Utils::WrappableString,nil] The
      #     default description, or `nil` not to set a default. See
      #     {Toys::Tool#desc=} for info on the format.
      #
      def generate_flag_desc(flag, data) # rubocop:disable Lint/UnusedMethodArgument
        name = flag.key.to_s.tr("_", "-").gsub(/[^\w-]/, "").downcase.inspect
        acceptable = flag.flag_type == :value ? acceptable_name(flag.accept) : "boolean flag"
        default_clause = flag.default ? " (default is #{flag.default.inspect})" : ""
        "Sets the #{name} option as type #{acceptable}#{default_clause}."
      end

      ##
      # This method implements logic for generating a flag long description.
      # Override this method to provide different logic.
      #
      # @param [Toys::Tool::FlagDefinition] flag The flag to document
      # @param [Hash] data Additional data that might be useful. Currently,
      #     the {Toys::Tool} is passed with key `:tool`. Future versions of
      #     Toys may provide additional information.
      # @return [Array<Toys::Utils::WrappableString,String,Array<String>>,nil]
      #     The default long description, or `nil` not to set a default. See
      #     {Toys::Tool#long_desc=} for info on the format.
      #
      def generate_flag_long_desc(flag, data) # rubocop:disable Lint/UnusedMethodArgument
        nil
      end

      ##
      # This method implements the logic for generating an arg description.
      # Override this method to provide different logic.
      #
      # @param [Toys::Tool::ArgDefinition] arg The arg to document
      # @param [Hash] data Additional data that might be useful. Currently,
      #     the {Toys::Tool} is passed with key `:tool`. Future versions of
      #     Toys may provide additional information.
      # @return [String,Array<String>,Toys::Utils::WrappableString,nil] The
      #     default description, or `nil` not to set a default. See
      #     {Toys::Tool#desc=} for info on the format.
      #
      def generate_arg_desc(arg, data) # rubocop:disable Lint/UnusedMethodArgument
        acceptable = acceptable_name(arg.accept)
        default_clause = arg.default ? " (default is #{arg.default.inspect})" : ""
        case arg.type
        when :required
          "Required #{acceptable} argument."
        when :optional
          "Optional #{acceptable} argument#{default_clause}."
        else
          "Remaining arguments are type #{acceptable}#{default_clause}."
        end
      end

      ##
      # This method implements logic for generating an arg long description.
      # Override this method to provide different logic.
      #
      # @param [Toys::Tool::ArgDefinition] arg The arg to document
      # @param [Hash] data Additional data that might be useful. Currently,
      #     the {Toys::Tool} is passed with key `:tool`. Future versions of
      #     Toys may provide additional information.
      # @return [Array<Toys::Utils::WrappableString,String,Array<String>>,nil]
      #     The default long description, or `nil` not to set a default. See
      #     {Toys::Tool#long_desc=} for info on the format.
      #
      def generate_arg_long_desc(arg, data) # rubocop:disable Lint/UnusedMethodArgument
        nil
      end

      ##
      # Return a reasonable name for an acceptor
      #
      # @param [Object] accept An acceptor to name
      # @return [String]
      #
      def acceptable_name(accept)
        ACCEPTABLE_NAMES[accept] || accept.to_s.downcase
      end

      private

      def config_desc(object, desc, long_desc)
        object.desc = desc if desc && object.desc.empty?
        object.long_desc = long_desc if long_desc && object.long_desc.empty?
      end
    end
  end
end
