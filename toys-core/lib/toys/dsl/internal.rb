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
                      .find_all { |name| /^[a-z]\w*$/.match?(name) }
                      .map { |name| [name, true] }.to_h
                      .freeze

      class << self
        ##
        # Called by the Loader and InputFile to prepare a tool class for running
        # the DSL.
        #
        # @private
        #
        def prepare(tool_class, words, priority, remaining_words, source, loader)
          unless tool_class.is_a?(DSL::Tool)
            class << tool_class
              alias_method :super_include, :include
            end
            tool_class.extend(DSL::Tool)
          end
          unless tool_class.instance_variable_defined?(:@__words)
            tool_class.instance_variable_set(:@__words, words)
            tool_class.instance_variable_set(:@__priority, priority)
            tool_class.instance_variable_set(:@__loader, loader)
            tool_class.instance_variable_set(:@__source, [])
          end
          tool_class.instance_variable_set(:@__remaining_words, remaining_words)
          tool_class.instance_variable_get(:@__source).push(source)
          old_source = ::Thread.current[:__toys_current_source]
          begin
            ::Thread.current[:__toys_current_source] = source
            yield
          ensure
            tool_class.instance_variable_get(:@__source).pop
            ::Thread.current[:__toys_current_source] = old_source
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
            priority = tool_class.instance_variable_get(:@__priority)
            cur_tool =
              if activate
                loader.activate_tool(words, priority)
              else
                loader.get_tool(words, priority)
              end
            if cur_tool && activate
              source = tool_class.instance_variable_get(:@__source).last
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
          subtool_words = tool_class.instance_variable_get(:@__words).dup
          next_remaining = tool_class.instance_variable_get(:@__remaining_words)
          loader.split_path(words).each do |word|
            word = word.to_s
            subtool_words << word
            next_remaining = Loader.next_remaining_words(next_remaining, word)
          end
          [subtool_words, next_remaining]
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
                      Compat.method_defined_without_ancestors?(tool_class, key)
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
            raise Toys::ToolDefinitionError, "Cannot load long desc from file type: #{path}"
          end
        end

        ##
        # Called by the Tool base class to set config values for a subclass.
        #
        # @private
        #
        def configure_class(tool_class, given_name = nil)
          return if tool_class.name.nil? || tool_class.instance_variable_defined?(:@__loader)

          mod_names = tool_class.name.split("::")
          class_name = mod_names.pop
          parent = parent_from_mod_name_segments(mod_names)
          loader = parent.instance_variable_get(:@__loader)
          name = given_name ? loader.split_path(given_name) : class_name_to_tool_name(class_name)

          priority = parent.instance_variable_get(:@__priority)
          words = parent.instance_variable_get(:@__words) + name
          subtool = loader.get_tool(words, priority, tool_class)

          remaining_words = parent.instance_variable_get(:@__remaining_words)
          next_remaining = name.reduce(remaining_words) do |running_words, word|
            Loader.next_remaining_words(running_words, word)
          end

          tool_class.instance_variable_set(:@__words, words)
          tool_class.instance_variable_set(:@__priority, priority)
          tool_class.instance_variable_set(:@__loader, loader)
          tool_class.instance_variable_set(:@__source, [current_source_from_context])
          tool_class.instance_variable_set(:@__remaining_words, next_remaining)
          tool_class.instance_variable_set(:@__cur_tool, subtool)
        end

        ##
        # Called by the Tool base class to add the DSL to a subclass.
        #
        # @private
        #
        def setup_class_dsl(tool_class)
          return if tool_class.name.nil? || tool_class.is_a?(DSL::Tool)
          class << tool_class
            alias_method :super_include, :include
          end
          tool_class.extend(DSL::Tool)
        end

        private

        def class_name_to_tool_name(class_name)
          name = class_name.to_s.sub(/^_+/, "").sub(/_+$/, "").gsub(/_+/, "-")
          while name.sub!(/([^-])([A-Z])/, "\\1-\\2") do end
          [name.downcase!]
        end

        def parent_from_mod_name_segments(mod_names)
          parent = mod_names.reduce(::Object) do |running_mod, seg|
            running_mod.const_get(seg)
          end
          if !parent.is_a?(::Toys::Tool) && parent.instance_variable_defined?(:@__tool_class)
            parent = parent.instance_variable_get(:@__tool_class)
          end
          unless parent.ancestors.include?(::Toys::Context)
            raise ToolDefinitionError, "Toys::Tool can be subclassed only from the Toys DSL"
          end
          parent
        end

        def current_source_from_context
          source = ::Thread.current[:__toys_current_source]
          if source.nil?
            raise ToolDefinitionError, "Toys::Tool can be subclassed only from a Toys config file"
          end
          unless source.source_type == :file
            raise ToolDefinitionError, "Toys::Tool cannot be subclassed inside a tool block"
          end
          source
        end
      end
    end
  end
end
