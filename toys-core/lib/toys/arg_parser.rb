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
  ##
  # An internal class that parses command line arguments for a tool.
  #
  # Generally, you should not need to use this class directly. It is called
  # from {Toys::Runner}.
  #
  class ArgParser
    ##
    # Create an argument parser for a particular tool.
    #
    # @param [Toys::ToolDefinition] tool_definition The tool defining the
    #     argument format.
    #
    def initialize(tool_definition)
      @tool_definition = tool_definition
      @seen_flag_keys = []
      @errors = []
      @extra_args = []
      @parsed_args = []
      @active_flag_def = nil
      @active_flag_arg = nil
      @arg_defs = tool_definition.arg_definitions
      @arg_def_index = 0
      @flags_allowed = true
      @data = duplicate_hash(tool_definition.default_data)
      @finished = false
    end

    ##
    # The tool definition governing this parser.
    # @return [Toys::ToolDefinition]
    #
    attr_reader :tool_definition

    ##
    # All command line arguments that have been parsed.
    # @return [Array<String>]
    #
    attr_reader :parsed_args

    ##
    # The collected tool data from parsed arguments.
    # @return [Hash]
    #
    attr_reader :data

    ##
    # An array of parse error messages.
    # @return [Array<String>]
    #
    attr_reader :errors

    ##
    # The current flag definition whose value is still pending, or `nil` if
    # there is no pending flag.
    # @return [Toys::Definition::Flag,nil]
    #
    attr_reader :active_flag_def

    ##
    # Whether flags are currently allowed. Returns false after `--` is received.
    # @return [Boolean]
    #
    attr_reader :flags_allowed
    alias flags_allowed? flags_allowed

    ##
    # Determine if this parser is finished
    # @return [Boolean]
    #
    attr_reader :finished
    alias finished? finished

    ##
    # The argument definition that will be applied to the next argument, or
    # `nil` if all arguments have been filled.
    # @return [Toys::Definition::Arg,nil]
    #
    def next_arg_def
      @arg_defs[@arg_def_index]
    end

    ##
    # Incrementally parse an array of strings
    #
    # @param [Array<String>] args
    # @return [Toys::ArgParser] self, for chaining.
    #
    def parse(args)
      args.each { |arg| add(arg) }
      self
    end

    ##
    # Incrementally parse a single string
    #
    # @param [String] arg
    # @return [Toys::ArgParser] self, for chaining.
    #
    def add(arg)
      raise "Parser has finished" if @finished
      @parsed_args << arg
      check_flag_value(arg) ||
        check_flag(arg) ||
        handle_positional(arg)
      self
    end

    ##
    # Complete parsing. This should be called after all arguments have been
    # processed. It does a final check for any errors, including:
    #
    # *   The arguments ended with a flag that was expecting a value but wasn't
    #     provided.
    # *   One or more required arguments were never given a value.
    # *   One or more extra arguments were provided.
    # *   Restrictions defined in one or more flag groups were not fulfilled.
    #
    # Any errors are added to the errors array.
    #
    # After this method is called, this object is locked down, and no
    # additional arguments may be parsed.
    #
    def finish
      finish_active_flag
      finish_arg_defs
      finish_flag_groups
      @finished = true
      self
    end

    private

    REMAINING_HANDLER = ->(val, prev) { prev.is_a?(::Array) ? prev << val : [val] }
    ARG_HANDLER = ->(val, _prev) { val }

    if ::RUBY_VERSION < "2.4"
      def duplicate_hash(orig)
        copy = {}
        orig.each do |k, v|
          copy[k] =
            begin
              v.clone
            rescue ::TypeError
              v
            end
        end
        copy
      end
    else
      def duplicate_hash(orig)
        copy = {}
        orig.each { |k, v| copy[k] = v.clone }
        copy
      end
    end

    def check_flag_value(arg)
      return false unless @active_flag_def
      result = @active_flag_def.value_type == :required || !arg.start_with?("-")
      add_data(@active_flag_def.key, @active_flag_def.handler, @active_flag_def.acceptor,
               result ? arg : nil, "flag", @active_flag_arg)
      @seen_flag_keys << @active_flag_def.key
      @active_flag_def = nil
      @active_flag_arg = nil
      result
    end

    def check_flag(arg)
      return false unless @flags_allowed
      case arg
      when "--"
        @flags_allowed = false
      when /\A(--\w[\?\w-]*)=(.*)\z/
        handle_valued_flag($1, $2)
      when /\A--.+\z/
        handle_plain_flag(arg)
      when /\A-(.+)\z/
        handle_single_flags($1)
      else
        return false
      end
      true
    end

    def handle_single_flags(str)
      until str.empty?
        str = handle_plain_flag("-#{str[0]}", str[1..-1])
      end
    end

    def handle_plain_flag(name, following = "")
      flag_result = find_flag(name)
      flag_def = flag_result.unique_flag
      return "" unless flag_def
      @seen_flag_keys << flag_def.key
      if flag_def.flag_type == :boolean
        add_data(flag_def.key, flag_def.handler, nil, !flag_result.unique_flag_negative?,
                 "flag", name)
      elsif following.empty?
        if flag_def.value_type == :required || flag_result.unique_flag_syntax.value_delim == " "
          @active_flag_def = flag_def
          @active_flag_arg = name
        else
          add_data(flag_def.key, flag_def.handler, flag_def.acceptor, nil, "flag", name)
        end
      else
        add_data(flag_def.key, flag_def.handler, flag_def.acceptor, following, "flag", name)
        following = ""
      end
      following
    end

    def handle_valued_flag(name, value)
      flag_result = find_flag(name)
      flag_def = flag_result.unique_flag
      return unless flag_def
      @seen_flag_keys << flag_def.key
      if flag_def.flag_type == :value
        add_data(flag_def.key, flag_def.handler, flag_def.acceptor, value, "flag", name)
      else
        add_data(flag_def.key, flag_def.handler, nil, !flag_result.unique_flag_negative?,
                 "flag", name)
        @errors << "Flag \"#{name}\" should not take an argument."
      end
    end

    def handle_positional(arg)
      if @tool_definition.flags_before_args_enforced?
        @flags_allowed = false
      end
      arg_def = next_arg_def
      unless arg_def
        @extra_args << arg
        return
      end
      @arg_def_index += 1 unless arg_def.type == :remaining
      handler = arg_def.type == :remaining ? REMAINING_HANDLER : ARG_HANDLER
      add_data(arg_def.key, handler, arg_def.acceptor, arg, "arg", arg_def.display_name)
    end

    def find_flag(name)
      flag_result = @tool_definition.resolve_flag(name)
      unless flag_result.found_unique?
        @errors << "Flag \"#{name}\" is not recognized." if flag_result.not_found?
        @errors << "Flag prefix \"#{name}\" is ambiguous." if flag_result.found_multiple?
      end
      flag_result
    end

    def add_data(key, handler, accept, value, type_name, display_name)
      if accept
        match = accept.match(value)
        unless match
          @errors << "Unacceptable value for #{type_name} \"#{display_name}\"."
          return
        end
        value = accept.convert(*Array(match))
      end
      if handler
        value = handler.call(value, @data[key])
      end
      @data[key] = value
    end

    def finish_active_flag
      if @active_flag_def
        if @active_flag_def.value_type == :required
          @errors << "Flag \"#{@active_flag_arg}\" is missing a value."
        else
          add_data(@active_flag_def.key, @active_flag_def.handler, @active_flag_def.acceptor,
                   nil, "flag", @active_flag_arg)
        end
      end
    end

    def finish_arg_defs
      arg_def = @arg_defs[@arg_def_index]
      if arg_def && arg_def.type == :required
        @errors << "Required argument \"#{arg_def.display_name}\" is missing."
      end
      unless @extra_args.empty?
        @errors <<
          if @tool_definition.runnable? || !@seen_flag_keys.empty?
            "Extra arguments: #{@extra_args.inspect}."
          else
            "Tool not found: #{(@tool_definition.full_name + parsed_args).inspect}."
          end
      end
    end

    def finish_flag_groups
      @tool_definition.flag_groups.each do |group|
        @errors += Array(group.validation_errors(@seen_flag_keys))
      end
    end
  end
end
