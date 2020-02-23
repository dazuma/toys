# frozen_string_literal: true

require "monitor"

module Toys
  ##
  # A helper module that provides methods to do module lookups. This is
  # used to obtain named helpers, middleware, and templates from the
  # respective modules.
  #
  class ModuleLookup
    class << self
      ##
      # Convert the given string to a path element. Specifically, converts
      # to `lower_snake_case`.
      #
      # @param str [String,Symbol] String to convert.
      # @return [String] Converted string
      #
      def to_path_name(str)
        str = str.to_s.sub(/^_/, "").sub(/_$/, "").gsub(/_+/, "_")
        while str.sub!(/([^_])([A-Z])/, "\\1_\\2") do end
        str.downcase
      end

      ##
      # Convert the given string to a module name. Specifically, converts
      # to `UpperCamelCase`, and then to a symbol.
      #
      # @param str [String,Symbol] String to convert.
      # @return [Symbol] Converted name
      #
      def to_module_name(str)
        str = str.to_s.sub(/^_/, "").sub(/_$/, "").gsub(/_+/, "_")
        str.to_s.gsub(/(?:^|_)([a-zA-Z])/) { ::Regexp.last_match(1).upcase }.to_sym
      end

      ##
      # Given a require path, return the module expected to be defined.
      #
      # @param path [String] File path, delimited by forward slash
      # @return [Module] The module loaded from that path
      #
      def path_to_module(path)
        path.split("/").reduce(::Object) do |running_mod, seg|
          mod_name = to_module_name(seg)
          unless running_mod.constants.include?(mod_name)
            raise ::NameError, "Module #{running_mod.name}::#{mod_name} not found"
          end
          running_mod.const_get(mod_name)
        end
      end
    end

    ##
    # Create an empty ModuleLookup
    #
    def initialize
      @mutex = ::Monitor.new
      @paths = []
      @paths_locked = false
    end

    ##
    # Add a lookup path for modules.
    #
    # @param path_base [String] The base require path
    # @param module_base [Module] The base module, or `nil` (the default) to
    #     infer a default from the path base.
    # @param high_priority [Boolean] If true, add to the head of the lookup
    #     path, otherwise add to the end.
    # @return [self]
    #
    def add_path(path_base, module_base: nil, high_priority: false)
      module_base ||= ModuleLookup.path_to_module(path_base)
      @mutex.synchronize do
        raise "You cannot add a path after a lookup has already occurred." if @paths_locked
        if high_priority
          @paths.unshift([path_base, module_base])
        else
          @paths << [path_base, module_base]
        end
      end
      self
    end

    ##
    # Obtain a named module. Returns `nil` if the name is not present.
    #
    # @param name [String,Symbol] The name of the module to return.
    # @return [Module] The specified module
    #
    def lookup(name)
      @mutex.synchronize do
        @paths_locked = true
        @paths.each do |path_base, module_base|
          path = "#{path_base}/#{ModuleLookup.to_path_name(name)}"
          begin
            require path
          rescue ::LoadError
            next
          end
          mod_name = ModuleLookup.to_module_name(name)
          unless module_base.constants.include?(mod_name)
            raise ::NameError,
                  "File #{path.inspect} did not define #{module_base.name}::#{mod_name}"
          end
          return module_base.const_get(mod_name)
        end
      end
      nil
    end
  end
end
