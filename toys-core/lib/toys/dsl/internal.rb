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
        # Called by the Loader and InputFile to prepare a tool class for running
        # the DSL, notably setting the standard class instance variables.
        # Also sets a thread-local that indicates whether the current source
        # is a proc source, which is necessary because subclasses cannot live
        # under a proc and need to detect that state.
        #
        # @private
        #
        def prepare(tool_class, words, remaining_words, source, loader)
          unless tool_class.is_a?(DSL::Tool)
            class << tool_class
              alias_method :include_module, :include
            end
            tool_class.extend(DSL::Tool)
          end
          tool_class.instance_variable_set(:@__words, words)
          tool_class.instance_variable_set(:@__loader, loader)
          tool_class.instance_variable_set(:@__remaining_words, remaining_words)

          old_source =
            if tool_class.instance_variable_defined?(:@__source)
              tool_class.instance_variable_get(:@__source)
            end
          old_is_proc_source = ::Thread.current[:__toys_is_proc_source]
          begin
            tool_class.instance_variable_set(:@__source, source)
            ::Thread.current[:__toys_is_proc_source] = source.source_type == :proc
            yield
          ensure
            # Leave the outermost source in place after the block to ensure
            # access doesn't blow up after loading finishes.
            tool_class.instance_variable_set(:@__source, old_source) if old_source
            ::Thread.current[:__toys_is_proc_source] = old_is_proc_source
          end
        end

        ##
        # Called by the DSL implementation to get, and optionally activate, the
        # current tool.
        #
        # @private
        #
        def current_tool(tool_class, activate)
          memoize_var = activate ? :@__active_tool : :@__cur_tool
          if tool_class.instance_variable_defined?(memoize_var)
            tool_class.instance_variable_get(memoize_var)
          else
            loader = tool_class.instance_variable_get(:@__loader)
            words = tool_class.instance_variable_get(:@__words)
            priority = tool_class.instance_variable_get(:@__source).priority
            cur_tool = loader.get_tool(words, priority, activate: activate)
            if cur_tool && activate
              source = tool_class.instance_variable_get(:@__source)
              cur_tool.lock_source(source)
            end
            tool_class.instance_variable_set(memoize_var, cur_tool)
          end
        end

        ##
        # Called by the DSL implementation to analyze the name of a new tool
        # definition in context.
        #
        # @private
        #
        def analyze_name(tool_class, words)
          loader = tool_class.instance_variable_get(:@__loader)
          loader.descend_name(tool_class.instance_variable_get(:@__words),
                              tool_class.instance_variable_get(:@__remaining_words),
                              loader.tool_name_splitter.split(words))
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
        # Called by the DSL implementation to find a named mixin.
        #
        # @private
        #
        def resolve_mixin(mixin, cur_tool, loader)
          mod =
            case mixin
            when ::String
              cur_tool.lookup_mixin(mixin)
            when ::Symbol
              loader.resolve_standard_mixin(mixin.to_s)
            when ::Module
              mixin
            end
          raise ToolDefinitionError, "Mixin not found: #{mixin.inspect}" unless mod
          mod
        end

        ##
        # Called by the DSL implementation to load a long description from a
        # file.
        #
        # @private
        #
        def load_long_desc_file(path)
          if ::File.extname(path) == ".txt"
            begin
              ::File.readlines(path).map do |line|
                line = line.chomp
                line =~ /^\s/ ? [line] : line
              end
            rescue ::SystemCallError => e
              raise Toys::ToolDefinitionError, e.to_s
            end
          else
            raise Toys::ToolDefinitionError, "Cannot load long desc from non-text file: #{path}"
          end
        end

        ##
        # Called by the Tool base class to set config values for a subclass.
        #
        # @private
        #
        def configure_class(tool_class, given_name = nil)
          # The name.nil? check is important to guard against this being run on
          # normal block-based tool classes where it shouldn't apply.
          return if tool_class.name.nil? || tool_class.instance_variable_defined?(:@__loader)
          validate_parent_source

          mod_names = tool_class.name.split("::")
          class_name = mod_names.pop
          parent_class = parent_from_mod_name_segments(mod_names)
          loader = parent_class.instance_variable_get(:@__loader)
          name = given_name ? loader.tool_name_splitter.split(given_name) : class_name_to_tool_name(class_name)
          source = parent_class.instance_variable_get(:@__source).subclass_child(tool_class)
          words, next_remaining =
            loader.descend_name(parent_class.instance_variable_get(:@__words),
                                parent_class.instance_variable_get(:@__remaining_words),
                                name)
          subtool = loader.get_tool(words, source.priority, tool_class: tool_class)

          tool_class.instance_variable_set(:@__words, words)
          tool_class.instance_variable_set(:@__loader, loader)
          tool_class.instance_variable_set(:@__source, source)
          tool_class.instance_variable_set(:@__remaining_words, next_remaining)
          tool_class.instance_variable_set(:@__cur_tool, subtool)
        end

        ##
        # Called by the Tool base class to add the DSL to a subclass.
        #
        # @private
        #
        def setup_class_dsl(tool_class)
          # The name.nil? check is important to guard against this being run on
          # normal block-based tool classes where it shouldn't apply.
          return if tool_class.name.nil? || tool_class.is_a?(DSL::Tool)
          class << tool_class
            alias_method :include_module, :include
          end
          tool_class.extend(DSL::Tool)
        end

        private

        def class_name_to_tool_name(class_name)
          name = class_name.to_s.sub(/^_+/, "").sub(/_+$/, "").gsub(/_+/, "-")
          while name.sub!(/([^-])([A-Z])/, "\\1-\\2") do end
          [name.downcase]
        end

        def parent_from_mod_name_segments(mod_names)
          parent = mod_names.reduce(::Object) do |running_mod, seg|
            running_mod.const_get(seg)
          end
          if parent.instance_variable_defined?(:@__tool_class)
            parent = parent.instance_variable_get(:@__tool_class)
          end
          unless parent.ancestors.include?(::Toys::Context)
            raise ToolDefinitionError, "Toys::Tool can be subclassed only from the Toys DSL"
          end
          parent
        end

        def validate_parent_source
          case ::Thread.current[:__toys_is_proc_source]
          when nil
            raise ToolDefinitionError, "Toys::Tool can be subclassed only from a Toys tool file"
          when true
            raise ToolDefinitionError, "Toys::Tool cannot be subclassed inside a tool block"
          end
        end
      end
    end
  end
end
