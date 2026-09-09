# frozen_string_literal: true

module Toys
  module DSL
    ##
    # Internal utility calls used by the DSL.
    #
    # @private
    #
    module Internal
      ##
      # @private A list of method names to avoid using as getters
      #
      AVOID_GETTERS = (::Object.instance_methods + [:run, :initialize])
                      .grep(/^[a-zA-Z]\w*$/)
                      .to_h { |name| [name, true] }
                      .freeze

      class << self
        ##
        # Called by the DSL implementation to get, and optionally activate, the
        # current tool.
        #
        # Always returns a non-nil tool if `activate` is false. If `activate`
        # is true, it could return `nil` if a higher priority tool has already
        # been activated.
        #
        # @private
        #
        def current_tool(tool_class, activate)
          current_load_state(tool_class).current_tool(activate)
        end

        ##
        # Get the LoadState for the given class. Called by the DSL.
        #
        # This method is here so that the DSL calls only methods of this module
        # rather than reaching directly into the Loader::LoadState namespace.
        #
        # @private
        #
        def current_load_state(tool_class)
          Loader::LoadState.get(tool_class)
        end

        ##
        # Called by the DSL implementation to add a getter to the tool class.
        #
        # @private
        #
        def maybe_add_getter(tool_class, key, force)
          return unless key.is_a?(::Symbol)
          case force
          when false
            return
          when true
            return unless /^[_a-zA-Z]\w*[!?]?$/.match(key.to_s)
          when nil
            return if !/^[a-zA-Z]\w*[!?]?$/.match?(key.to_s) ||
                      AVOID_GETTERS.key?(key) ||
                      tool_class.method_defined?(key, false) ||
                      tool_class.private_method_defined?(key, false)
          end
          tool_class.class_eval do
            define_method(key) do
              self[key]
            end
          end
        end

        ##
        # Called by the DSL implementation to load a long description from a
        # file.
        #
        # @private
        #
        def load_long_desc_file(path)
          unless ::File.extname(path) == ".txt"
            raise Toys::ToolDefinitionError, "Cannot load long desc from non-text file: #{path}"
          end
          begin
            ::File.readlines(path).map do |line|
              line = line.chomp
              line =~ /^\s/ ? [line] : line
            end
          rescue ::SystemCallError => e
            raise Toys::ToolDefinitionError, e.to_s
          end
        end

        ##
        # Called by the Tool base class from its inherited hooks. Anonymous
        # classes are skipped because they are not tools. (The load path calls
        # setup_class_dsl directly, because the tool classes it prepares are
        # anonymous.)
        #
        # @private
        #
        def setup_subclass_dsl(tool_class)
          setup_class_dsl(tool_class) unless tool_class.name.nil?
        end

        ##
        # Called by the Loader, InputFile, and the Tool base class to add the
        # DSL to a tool class.
        #
        # @private
        #
        def setup_class_dsl(tool_class)
          return if tool_class.is_a?(DSL::Tool)
          class << tool_class
            alias_method :include_module, :include
          end
          tool_class.extend(DSL::Tool)
        end
      end
    end
  end
end
