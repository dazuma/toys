# frozen_string_literal: true

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

module Toys
  module Utils
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
        # @param [String,Symbol] str String to convert.
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
        # @param [String,Symbol] str String to convert.
        # @return [Symbol] Converted name
        #
        def to_module_name(str)
          str = str.to_s.sub(/^_/, "").sub(/_$/, "").gsub(/_+/, "_")
          str.to_s.gsub(/(^|_)([a-zA-Z])/) { |_m| $2.upcase }.to_sym
        end

        ##
        # Given a require path, return the module expected to be defined.
        #
        # @param [String] path File path, delimited by forward slash
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
        @paths = []
      end

      ##
      # Add a lookup path for modules.
      #
      # @param [String] path_base The base require path
      # @param [Module] module_base The base module, or `nil` (the default) to
      #     infer a default from the path base.
      # @param [Boolean] high_priority If true, add to the head of the lookup
      #     path, otherwise add to the end.
      #
      def add_path(path_base, module_base: nil, high_priority: false)
        module_base ||= ModuleLookup.path_to_module(path_base)
        if high_priority
          @paths.unshift([path_base, module_base])
        else
          @paths << [path_base, module_base]
        end
        self
      end

      ##
      # Obtain a named module. Returns `nil` if the name is not present.
      #
      # @param [String,Symbol] name The name of the module to return.
      #
      # @return [Module] The specified module
      #
      def lookup(name)
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
        nil
      end
    end
  end
end
