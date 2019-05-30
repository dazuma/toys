# frozen_string_literal: true

# Copyright 2019 Daniel Azuma
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
# IN THE SOFTWARE.
;

module Toys
  module StandardMiddleware
    ##
    # This middleware sets default description fields for tools and command
    # line arguments and flags that do not have them set otherwise.
    #
    # You can modify the static descriptions for tools, namespaces, and the
    # root tool by passing parameters to this middleware. For finer control,
    # you can override methods to modify the description generation logic.
    #
    class SetDefaultDescriptions
      include Middleware

      ##
      # The default description for tools.
      # @return [String]
      #
      DEFAULT_TOOL_DESC = "(No tool description available)"

      ##
      # The default description for namespaces.
      # @return [String]
      #
      DEFAULT_NAMESPACE_DESC = "(A namespace of tools)"

      ##
      # The default description for the root tool.
      # @return [String]
      #
      DEFAULT_ROOT_DESC = "Command line tool built using the toys-core gem."

      ##
      # The default long description for the root tool.
      # @return [String]
      #
      DEFAULT_ROOT_LONG_DESC = [
        "This command line tool was built using the toys-core gem. See" \
          " https://www.rubydoc.info/gems/toys-core for more info.",
        "To replace this message, set the description and long description" \
          " of the root tool, or configure the SetDefaultDescriptions" \
          " middleware.",
      ].freeze

      ##
      # A mapping of names for acceptable types
      # @return [Hash]
      #
      ACCEPTABLE_NAMES = {
        nil => "string",
        ::Object => "string",
        ::NilClass => "string",
        ::String => "nonempty string",
        ::TrueClass => "boolean",
        ::FalseClass => "boolean",
        ::Array => "string array",
        ::Regexp => "regular expression",
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
      # @return [String,Array<String>,Toys::WrappableString,nil] The default
      #     description, or `nil` not to set a default. See {Toys::Tool#desc=}
      #     for info on the format.
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
      # @return [Array<Toys::WrappableString,String,Array<String>>,nil] The
      #     default long description, or `nil` not to set a default. See
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
      # @return [String,Array<String>,Toys::WrappableString,nil] The default
      #     description, or `nil` not to set a default. See {Toys::Tool#desc=}
      #     for info on the format.
      #
      def generate_flag_desc(flag, data) # rubocop:disable Lint/UnusedMethodArgument
        name = flag.key.to_s.tr("_", "-").gsub(/[^\w-]/, "").downcase.inspect
        acceptable = flag.flag_type == :value ? acceptable_name(flag.acceptor) : "boolean flag"
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
      # @return [Array<Toys::WrappableString,String,Array<String>>,nil] The
      #     default long description, or `nil` not to set a default. See
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
      # @return [String,Array<String>,Toys::WrappableString,nil] The default
      #     description, or `nil` not to set a default. See {Toys::Tool#desc=}
      #     for info on the format.
      #
      def generate_arg_desc(arg, data) # rubocop:disable Lint/UnusedMethodArgument
        acceptable = acceptable_name(arg.acceptor)
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
      # @return [Array<Toys::WrappableString,String,Array<String>>,nil] The
      #     default long description, or `nil` not to set a default. See
      #     {Toys::Tool#long_desc=} for info on the format.
      #
      def generate_arg_long_desc(arg, data) # rubocop:disable Lint/UnusedMethodArgument
        nil
      end

      ##
      # Return a reasonable name for an acceptor
      #
      # @param [Toys::Acceptor::Base,nil] accept An acceptor to name
      # @return [String]
      #
      def acceptable_name(accept)
        name = accept&.name
        str = ACCEPTABLE_NAMES[name]
        if str.nil? && defined?(::OptionParser)
          str =
            if name == ::OptionParser::DecimalInteger
              "decimal integer"
            elsif name == ::OptionParser::OctalInteger
              "octal integer"
            elsif name == ::OptionParser::DecimalNumeric
              "decimal numeric"
            end
        end
        str || name.to_s.downcase
      end

      private

      def config_desc(object, desc, long_desc)
        object.desc = desc if desc && object.desc.empty?
        object.long_desc = long_desc if long_desc && object.long_desc.empty?
      end
    end
  end
end
