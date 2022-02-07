# frozen_string_literal: true

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
      ##
      # The default description for tools.
      # @return [String]
      #
      DEFAULT_TOOL_DESC = "(No tool description available)"

      ##
      # The default description for delegating tools.
      # @return [String]
      #
      DEFAULT_DELEGATE_DESC = '(Delegates to "%<target>s")'

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
          " https://dazuma.github.io/toys/gems/toys-core for more info.",
        "To replace this message, set the description and long description" \
          " of the root tool, or configure the SetDefaultDescriptions" \
          " middleware.",
      ].freeze

      ##
      # Create a SetDefaultDescriptions middleware given default descriptions.
      #
      # @param default_tool_desc [String,nil] The default short description for
      #     runnable tools, or `nil` not to set one. Defaults to
      #     {DEFAULT_TOOL_DESC}.
      # @param default_tool_long_desc [Array<String>,nil] The default long
      #     description for runnable tools, or `nil` not to set one. Defaults
      #     to `nil`.
      # @param default_namespace_desc [String,nil] The default short
      #     description for non-runnable tools, or `nil` not to set one.
      #     Defaults to {DEFAULT_TOOL_DESC}.
      # @param default_namespace_long_desc [Array<String>,nil] The default long
      #     description for non-runnable tools, or `nil` not to set one.
      #     Defaults to `nil`.
      # @param default_root_desc [String,nil] The default short description for
      #     the root tool, or `nil` not to set one. Defaults to
      #     {DEFAULT_ROOT_DESC}.
      # @param default_root_long_desc [Array<String>,nil] The default long
      #     description for the root tool, or `nil` not to set one. Defaults to
      #     {DEFAULT_ROOT_LONG_DESC}.
      # @param default_delegate_desc [String,nil] The default short description
      #     for delegate tools, or `nil` not to set one. May include an sprintf
      #     field for the `target` name. Defaults to {DEFAULT_DELEGATE_DESC}.
      #
      def initialize(default_tool_desc: DEFAULT_TOOL_DESC,
                     default_tool_long_desc: nil,
                     default_namespace_desc: DEFAULT_NAMESPACE_DESC,
                     default_namespace_long_desc: nil,
                     default_root_desc: DEFAULT_ROOT_DESC,
                     default_root_long_desc: DEFAULT_ROOT_LONG_DESC,
                     default_delegate_desc: DEFAULT_DELEGATE_DESC)
        @default_tool_desc = default_tool_desc
        @default_tool_long_desc = default_tool_long_desc
        @default_namespace_desc = default_namespace_desc
        @default_namespace_long_desc = default_namespace_long_desc
        @default_root_desc = default_root_desc
        @default_root_long_desc = default_root_long_desc
        @default_delegate_desc = default_delegate_desc
      end

      ##
      # Add default description text to tools.
      #
      # @private
      #
      def config(tool, loader)
        data = {tool: tool, loader: loader}
        tool.flags.each do |flag|
          config_desc(flag, generate_flag_desc(flag, data), generate_flag_long_desc(flag, data))
        end
        tool.positional_args.each do |arg|
          config_desc(arg, generate_arg_desc(arg, data), generate_arg_long_desc(arg, data))
        end
        tool.flag_groups.each do |flag_group|
          config_desc(flag_group, generate_flag_group_desc(flag_group, data),
                      generate_flag_group_long_desc(flag_group, data))
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
      # @param tool [Toys::ToolDefinition] The tool to document.
      # @param data [Hash] Additional data that might be useful. Currently,
      #     the {Toys::Loader} is passed with key `:loader`. Future versions
      #     of Toys may provide additional information.
      # @return [String,Array<String>,Toys::WrappableString] The default
      #     description. See {Toys::DSL::Tool#desc} for info on the format.
      # @return [nil] if this middleware should not set the description.
      #
      def generate_tool_desc(tool, data)
        if tool.root?
          @default_root_desc
        elsif tool.delegate_target
          params = {target: tool.delegate_target.join(" ")}
          format(@default_delegate_desc, params)
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
      # @param tool [Toys::ToolDefinition] The tool to document
      # @param data [Hash] Additional data that might be useful. Currently,
      #     the {Toys::Loader} is passed with key `:loader`. Future versions of
      #     Toys may provide additional information.
      # @return [Array<Toys::WrappableString,String,Array<String>>] The default
      #     long description. See {Toys::DSL::Tool#long_desc} for info on the
      #     format.
      # @return [nil] if this middleware should not set the long description.
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
      # @param flag [Toys::Flag] The flag to document
      # @param data [Hash] Additional data that might be useful. Currently,
      #     the {Toys::ToolDefinition} is passed with key `:tool`. Future
      #     versions of Toys may provide additional information.
      # @return [String,Array<String>,Toys::WrappableString] The default
      #     description. See {Toys::DSL::Tool#desc} for info on the format.
      # @return [nil] if this middleware should not set the description.
      #
      def generate_flag_desc(flag, data) # rubocop:disable Lint/UnusedMethodArgument
        name = flag.key.to_s.tr("_", "-").gsub(/[^\w-]/, "").downcase.inspect
        acceptable = flag.flag_type == :value ? flag.acceptor.type_desc : "boolean flag"
        default_clause = flag.default ? " (default is #{flag.default.inspect})" : ""
        "Sets the #{name} option as type #{acceptable}#{default_clause}."
      end

      ##
      # This method implements logic for generating a flag long description.
      # Override this method to provide different logic.
      #
      # @param flag [Toys::Flag] The flag to document
      # @param data [Hash] Additional data that might be useful. Currently,
      #     the {Toys::ToolDefinition} is passed with key `:tool`. Future
      #     versions of Toys may provide additional information.
      # @return [Array<Toys::WrappableString,String,Array<String>>] The default
      #     long description. See {Toys::DSL::Tool#long_desc} for info on the
      #     format.
      # @return [nil] if this middleware should not set the long description.
      #
      def generate_flag_long_desc(flag, data) # rubocop:disable Lint/UnusedMethodArgument
        nil
      end

      ##
      # This method implements the logic for generating an arg description.
      # Override this method to provide different logic.
      #
      # @param arg [Toys::PositionalArg] The arg to document
      # @param data [Hash] Additional data that might be useful. Currently,
      #     the {Toys::ToolDefinition} is passed with key `:tool`. Future
      #     versions of Toys may provide additional information.
      # @return [String,Array<String>,Toys::WrappableString] The default
      #     description. See {Toys::DSL::Tool#desc} for info on the format.
      # @return [nil] if this middleware should not set the description.
      #
      def generate_arg_desc(arg, data) # rubocop:disable Lint/UnusedMethodArgument
        acceptable = arg.acceptor.type_desc
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
      # @param arg [Toys::PositionalArg] The arg to document
      # @param data [Hash] Additional data that might be useful. Currently,
      #     the {Toys::ToolDefinition} is passed with key `:tool`. Future
      #     versions of Toys may provide additional information.
      # @return [Array<Toys::WrappableString,String,Array<String>>] The default
      #     long description. See {Toys::DSL::Tool#long_desc} for info on the
      #     format.
      # @return [nil] if this middleware should not set the long description.
      #
      def generate_arg_long_desc(arg, data) # rubocop:disable Lint/UnusedMethodArgument
        nil
      end

      ##
      # This method implements the logic for generating a flag group
      # description. Override this method to provide different logic.
      #
      # @param group [Toys::FlagGroup] The flag group to document
      # @param data [Hash] Additional data that might be useful. Currently,
      #     the {Toys::ToolDefinition} is passed with key `:tool`. Future
      #     versions of Toys may provide additional information.
      # @return [String,Array<String>,Toys::WrappableString] The default
      #     description. See {Toys::DSL::Tool#desc} for info on the format.
      # @return [nil] if this middleware should not set the description.
      #
      def generate_flag_group_desc(group, data) # rubocop:disable Lint/UnusedMethodArgument
        if group.is_a?(FlagGroup::Required)
          "Required Flags"
        else
          "Flags"
        end
      end

      ##
      # This method implements the logic for generating a flag group long
      # description. Override this method to provide different logic.
      #
      # @param group [Toys::FlagGroup] The flag group to document
      # @param data [Hash] Additional data that might be useful. Currently,
      #     the {Toys::ToolDefinition} is passed with key `:tool`. Future
      #     versions of Toys may provide additional information.
      # @return [Array<Toys::WrappableString,String,Array<String>>] The default
      #     long description. See {Toys::DSL::Tool#long_desc} for info on the
      #     format.
      # @return [nil] if this middleware should not set the long description.
      #
      def generate_flag_group_long_desc(group, data) # rubocop:disable Lint/UnusedMethodArgument
        case group
        when FlagGroup::Required
          ["These flags are required."]
        when FlagGroup::ExactlyOne
          ["Exactly one of these flags must be set."]
        when FlagGroup::AtMostOne
          ["At most one of these flags must be set."]
        when FlagGroup::AtLeastOne
          ["At least one of these flags must be set."]
        end
      end

      private

      def config_desc(object, desc, long_desc)
        object.desc = desc if desc && object.desc.empty?
        object.long_desc = long_desc if long_desc && object.long_desc.empty?
      end
    end
  end
end
