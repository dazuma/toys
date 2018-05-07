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
  ##
  # An alias is a name that refers to another name.
  #
  class Alias
    ##
    # Create a new alias.
    #
    # @param [Array<String>] full_name The name of the alias.
    # @param [String,Array<String>] target The name of the target. May either
    #     be a local reference (a single string) or a global reference (an
    #     array of strings)
    #
    def initialize(full_name, target)
      @target_name =
        if target.is_a?(::String)
          full_name[0..-2] + [target]
        else
          target.dup
        end
      @target_name.freeze
      @full_name = full_name.dup.freeze
    end

    ##
    # Return the name of the tool as an array of strings.
    # This array may not be modified.
    # @return [Array<String>]
    #
    attr_reader :full_name

    ##
    # Return the name of the target as an array of strings.
    # This array may not be modified.
    # @return [Array<String>]
    #
    attr_reader :target_name

    ##
    # Returns the local name of this tool.
    # @return [String]
    #
    def simple_name
      full_name.last
    end

    ##
    # Returns a displayable name of this tool, generally the full name
    # delimited by spaces.
    # @return [String]
    #
    def display_name
      full_name.join(" ")
    end

    ##
    # Returns a displayable name of the target, generally the full name
    # delimited by spaces.
    # @return [String]
    #
    def display_target
      target_name.join(" ")
    end
  end
end
