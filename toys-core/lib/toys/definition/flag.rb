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
  module Definition
    ##
    # Representation of a single flag.
    #
    class FlagSyntax
      ##
      # Parse flag syntax
      # @param [String] str syntax.
      #
      def initialize(str)
        case str
        when /^(-[\?\w])$/
          setup(str, [$1], $1, "-", nil, nil, nil, nil)
        when /^(-[\?\w])( ?)\[(\w+)\]$/
          setup(str, [$1], $1, "-", :value, :optional, $2, $3)
        when /^(-[\?\w])\[( )(\w+)\]$/
          setup(str, [$1], $1, "-", :value, :optional, $2, $3)
        when /^(-[\?\w])( ?)(\w+)$/
          setup(str, [$1], $1, "-", :value, :required, $2, $3)
        when /^--\[no-\](\w[\?\w-]*)$/
          setup(str, ["--#{$1}", "--no-#{$1}"], str, "--", :boolean, nil, nil, nil)
        when /^(--\w[\?\w-]*)$/
          setup(str, [$1], $1, "--", nil, nil, nil, nil)
        when /^(--\w[\?\w-]*)([= ])\[(\w+)\]$/
          setup(str, [$1], $1, "--", :value, :optional, $2, $3)
        when /^(--\w[\?\w-]*)\[([= ])(\w+)\]$/
          setup(str, [$1], $1, "--", :value, :optional, $2, $3)
        when /^(--\w[\?\w-]*)([= ])(\w+)$/
          setup(str, [$1], $1, "--", :value, :required, $2, $3)
        else
          raise ToolDefinitionError, "Illegal flag: #{str.inspect}"
        end
      end

      attr_reader :original_str
      attr_reader :flags
      attr_reader :str_without_value
      attr_reader :flag_style
      attr_reader :flag_type
      attr_reader :value_type
      attr_reader :value_delim
      attr_reader :value_label
      attr_reader :canonical_str

      ## @private
      def configure_canonical(canonical_flag_type, canonical_value_type,
                              canonical_value_label, canonical_value_delim)
        return unless flag_type.nil?
        @flag_type = canonical_flag_type
        return unless canonical_flag_type == :value
        @value_type = canonical_value_type
        canonical_value_delim = "" if canonical_value_delim == "=" && flag_style == "-"
        canonical_value_delim = "=" if canonical_value_delim == "" && flag_style == "--"
        @value_delim = canonical_value_delim
        @value_label = canonical_value_label
        label = @value_type == :optional ? "[#{@value_label}]" : @value_label
        @canonical_str = "#{str_without_value}#{@value_delim}#{label}"
      end

      private

      def setup(original_str, flags, str_without_value, flag_style, flag_type, value_type,
                value_delim, value_label)
        @original_str = original_str
        @flags = flags
        @str_without_value = str_without_value
        @flag_style = flag_style
        @flag_type = flag_type
        @value_type = value_type
        @value_delim = value_delim
        @value_label = value_label ? value_label.upcase : value_label
        @canonical_str = original_str
      end
    end

    ##
    # Representation of a formal set of flags that set a particular context
    # key. The flags within a single Flag definition are synonyms.
    #
    class Flag
      ##
      # The default handler replaces the previous value.
      # @return [Proc]
      #
      DEFAULT_HANDLER = ->(val, _prev) { val }

      ##
      # Create a Flag definition
      # @private
      #
      def initialize(key, flags, used_flags, report_collisions, accept, handler, default)
        @key = key
        @flag_syntax = flags.map { |s| FlagSyntax.new(s) }
        @accept = accept
        @handler = handler || DEFAULT_HANDLER
        @desc = Utils::WrappableString.make(desc)
        @long_desc = Utils::WrappableString.make_array(long_desc)
        @default = default
        needs_val = (!accept.nil? && accept != ::TrueClass && accept != ::FalseClass) ||
                    (!default.nil? && default != true && default != false)
        create_default_flag_if_needed(needs_val)
        remove_used_flags(used_flags, report_collisions)
        canonicalize(needs_val)
      end

      ##
      # Returns the key.
      # @return [Symbol]
      #
      attr_reader :key

      ##
      # Returns an array of FlagSyntax for the flags.
      # @return [Array<FlagSyntax>]
      #
      attr_reader :flag_syntax

      ##
      # Returns the acceptor, which may be `nil`.
      # @return [Object]
      #
      attr_reader :accept

      ##
      # Returns the default value, which may be `nil`.
      # @return [Object]
      #
      attr_reader :default

      ##
      # Returns the short description string.
      # @return [Toys::Utils::WrappableString]
      #
      attr_reader :desc

      ##
      # Returns the long description strings as an array.
      # @return [Array<Toys::Utils::WrappableString>]
      #
      attr_reader :long_desc

      ##
      # Returns the handler for setting/updating the value.
      # @return [Proc]
      #
      attr_reader :handler

      ##
      # The type of flag. Possible values are `:boolean` for a simple boolean
      # switch, or `:value` for a flag that sets a value.
      # @return [:boolean,:value]
      #
      attr_reader :flag_type

      ##
      # The type of value. Set to `:required` or `:optional` if the flag type
      # is `:value`. Otherwise set to `nil`.
      # @return [:required,:optional,nil]
      #
      attr_reader :value_type

      ##
      # The string label for the value as it should display in help, or `nil`
      # if the flag type is not `:value`.
      # @return [String,nil]
      #
      attr_reader :value_label

      ##
      # The value delimiter, which may be `""`, `" "`, or `"="`. Set to `nil`
      # if the flag type is not `:value`.
      # @return [String,nil]
      #
      attr_reader :value_delim

      ##
      # Returns an array of FlagSyntax including only single-dash flags
      # @return [Array<FlagSyntax>]
      #
      def single_flag_syntax
        @single_flag_syntax ||= flag_syntax.find_all { |ss| ss.flag_style == "-" }
      end

      ##
      # Returns an array of FlagSyntax including only double-dash flags
      # @return [Array<FlagSyntax>]
      #
      def double_flag_syntax
        @double_flag_syntax ||= flag_syntax.find_all { |ss| ss.flag_style == "--" }
      end

      ##
      # Returns the list of effective flags used.
      # @return [Array<String>]
      #
      def effective_flags
        @effective_flags ||= flag_syntax.map(&:flags).flatten
      end

      ##
      # Returns a list suitable for passing to OptionParser.
      # @return [Array]
      #
      def optparser_info
        @optparser_info ||= flag_syntax.map(&:canonical_str) + Array(accept)
      end

      ##
      # Returns true if this flag is active. That is, it has a nonempty
      # flags list.
      # @return [Boolean]
      #
      def active?
        !effective_flags.empty?
      end

      ##
      # Set the short description string.
      #
      # The description may be provided as a {Toys::Utils::WrappableString}, a
      # single string (which will be wrapped), or an array of strings, which will
      # be interpreted as string fragments that will be concatenated and wrapped.
      #
      # @param [Toys::Utils::WrappableString,String,Array<String>] desc
      #
      def desc=(desc)
        @desc = Utils::WrappableString.make(desc)
      end

      ##
      # Set the long description strings.
      #
      # Each string may be provided as a {Toys::Utils::WrappableString}, a single
      # string (which will be wrapped), or an array of strings, which will be
      # interpreted as string fragments that will be concatenated and wrapped.
      #
      # @param [Array<Toys::Utils::WrappableString,String,Array<String>>] long_desc
      #
      def long_desc=(long_desc)
        @long_desc = Utils::WrappableString.make_array(long_desc)
      end

      private

      def create_default_flag_if_needed(needs_val)
        return unless @flag_syntax.empty?
        canonical_flag = key.to_s.downcase.tr("_", "-").gsub(/[^a-z0-9-]/, "").sub(/^-+/, "")
        unless canonical_flag.empty?
          flag = needs_val ? "--#{canonical_flag} VALUE" : "--#{canonical_flag}"
          @flag_syntax << FlagSyntax.new(flag)
        end
      end

      def remove_used_flags(used_flags, report_collisions)
        @flag_syntax.select! do |fs|
          fs.flags.all? do |f|
            collision = used_flags.include?(f)
            if collision && report_collisions
              raise ToolDefinitionError,
                    "Cannot use flag #{f.inspect} because it is already assigned or reserved."
            end
            !collision
          end
        end
        used_flags.concat(effective_flags.uniq)
      end

      def canonicalize(needs_val)
        @flag_type = needs_val ? :value : nil
        @value_type = nil
        @value_label = needs_val ? "VALUE" : nil
        @value_delim = " "
        single_flag_syntax.each do |flag|
          analyze_flag_syntax(flag)
        end
        double_flag_syntax.each do |flag|
          analyze_flag_syntax(flag)
        end
        @flag_type ||= :boolean
        flag_syntax.each do |flag|
          flag.configure_canonical(@flag_type, @value_type, @value_label, @value_delim)
        end
      end

      def analyze_flag_syntax(flag)
        return if flag.flag_type.nil?
        if !@flag_type.nil? && @flag_type != flag.flag_type
          raise ToolDefinitionError, "Cannot have both value and boolean flags for #{key.inspect}"
        end
        @flag_type = flag.flag_type
        return unless @flag_type == :value
        if !@value_type.nil? && @value_type != flag.value_type
          raise ToolDefinitionError,
                "Cannot have both required and optional values for flag #{key.inspect}"
        end
        @value_type = flag.value_type
        @value_label = flag.value_label
        @value_delim = flag.value_delim
      end
    end
  end
end
