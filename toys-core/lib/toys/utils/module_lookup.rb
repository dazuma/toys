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
    # You generally do not need to use these module methods directly. Instead
    # use the convenience methods {Toys::Helpers.lookup},
    # {Toys::Middleware.lookup}, or {Toys::Templates.lookup}.
    #
    module ModuleLookup
      class << self
        ##
        # Convert the given string to a path element. Specifically, converts
        # to `lower_snake_case`.
        #
        # @param [String,Symbol] str String to convert.
        # @return [String] Converted string
        #
        def to_path_name(str)
          str.to_s.gsub(/([a-zA-Z])([A-Z])/) { |_m| "#{$1}_#{$2.downcase}" }.downcase
        end

        ##
        # Convert the given string to a module name. Specifically, converts
        # to `UpperCamelCase`, and then to a symbol.
        #
        # @param [String,Symbol] str String to convert.
        # @return [Symbol] Converted name
        #
        def to_module_name(str)
          str.to_s.gsub(/(^|_)([a-zA-Z0-9])/) { |_m| $2.upcase }.to_sym
        end

        ##
        # Obtain a named module from the given collection. Raises an exception
        # on failure.
        #
        # @param [String,Symbol] collection The collection to search. Typical
        #     values are `:helpers`, `:middleware`, and `:templates`.
        # @param [String,Symbol] name The name of the module to return.
        #
        # @return [Module] The specified module
        # @raise [LoadError] No Ruby file containing the given module could
        #     be found.
        # @raise [NameError] The given module was not defined.
        #
        def lookup!(collection, name)
          require "toys/#{to_path_name(collection)}/#{to_path_name(name)}"
          collection_sym = to_module_name(collection)
          unless ::Toys.constants.include?(collection_sym)
            raise ::NameError, "Module does not exist: Toys::#{collection_sym}"
          end
          collection_mod = ::Toys.const_get(collection_sym)
          name_sym = to_module_name(name)
          unless collection_mod.constants.include?(name_sym)
            raise ::NameError, "Module does not exist: Toys::#{collection_sym}::#{name_sym}"
          end
          collection_mod.const_get(name_sym)
        end

        ##
        # Obtain a named module from the given collection. Returns `nil` on
        # failure.
        #
        # @param [String,Symbol] collection The collection to search. Typical
        #     values are `:helpers`, `:middleware`, and `:templates`.
        # @param [String,Symbol] name The name of the module to return.
        #
        # @return [Module,nil] The specified module, or `nil` if not found.
        #
        def lookup(collection, name)
          lookup!(collection, name)
        rescue ::NameError, ::LoadError
          nil
        end
      end
    end
  end
end
