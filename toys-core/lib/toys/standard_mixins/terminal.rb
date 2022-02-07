# frozen_string_literal: true

module Toys
  module StandardMixins
    ##
    # A mixin that provides a simple terminal. It includes a set of methods
    # that produce styled output, get user input, and otherwise interact with
    # the user's terminal. This mixin is not as richly featured as other mixins
    # such as Highline, but it has no gem dependencies so is ideal for basic
    # cases.
    #
    # You may make these methods available to your tool by including the
    # following directive in your tool configuration:
    #
    #     include :terminal
    #
    # A Terminal object will then be available by calling the {#terminal}
    # method. For information on using this object, see the documentation for
    # {Toys::Utils::Terminal}. Some of the most useful methods are also mixed
    # into the tool and can be called directly.
    #
    # You can configure the Terminal object by passing options to the `include`
    # directive. For example:
    #
    #     include :terminal, styled: true
    #
    # The arguments will be passed on to {Toys::Utils::Terminal#initialize}.
    #
    module Terminal
      include Mixin

      ##
      # Context key for the terminal object.
      # @return [Object]
      #
      KEY = ::Object.new.freeze

      ##
      # A tool-wide terminal instance
      # @return [Toys::Utils::Terminal]
      #
      def terminal
        self[KEY]
      end

      ##
      # Write a line, appending a newline if one is not already present.
      #
      # @see Toys::Utils::Terminal#puts
      #
      # @param str [String] The line to write
      # @param styles [Symbol,String,Array<Integer>...] Styles to apply to the
      #     entire line.
      # @return [self]
      #
      def puts(str = "", *styles)
        terminal.puts(str, *styles)
        self
      end
      alias say puts

      ##
      # Write a partial line without appending a newline.
      #
      # @see Toys::Utils::Terminal#write
      #
      # @param str [String] The line to write
      # @param styles [Symbol,String,Array<Integer>...] Styles to apply to the
      #     partial line.
      # @return [self]
      #
      def write(str = "", *styles)
        terminal.write(str, *styles)
        self
      end

      ##
      # Ask a question and get a response.
      #
      # @see Toys::Utils::Terminal#ask
      #
      # @param prompt [String] Required prompt string.
      # @param styles [Symbol,String,Array<Integer>...] Styles to apply to the
      #     prompt.
      # @param default [String,nil] Default value, or `nil` for no default.
      #     Uses `nil` if not specified.
      # @param trailing_text [:default,String,nil] Trailing text appended to
      #     the prompt, `nil` for none, or `:default` to show the default.
      # @return [String]
      #
      def ask(prompt, *styles, default: nil, trailing_text: :default)
        terminal.ask(prompt, *styles, default: default, trailing_text: trailing_text)
      end

      ##
      # Confirm with the user.
      #
      # @see Toys::Utils::Terminal#confirm
      #
      # @param prompt [String] Prompt string. Defaults to `"Proceed?"`.
      # @param styles [Symbol,String,Array<Integer>...] Styles to apply to the
      #     prompt.
      # @param default [Boolean,nil] Default value, or `nil` for no default.
      #     Uses `nil` if not specified.
      # @return [Boolean]
      #
      def confirm(prompt = "Proceed?", *styles, default: nil)
        terminal.confirm(prompt, *styles, default: default)
      end

      ##
      # Display a spinner during a task. You should provide a block that
      # performs the long-running task. While the block is executing, a
      # spinner will be displayed.
      #
      # @see Toys::Utils::Terminal#spinner
      #
      # @param leading_text [String] Optional leading string to display to the
      #     left of the spinner. Default is the empty string.
      # @param frame_length [Float] Length of a single frame, in seconds.
      #     Defaults to {Toys::Utils::Terminal::DEFAULT_SPINNER_FRAME_LENGTH}.
      # @param frames [Array<String>] An array of frames. Defaults to
      #     {Toys::Utils::Terminal::DEFAULT_SPINNER_FRAMES}.
      # @param style [Symbol,Array<Symbol>] A terminal style or array of styles
      #     to apply to all frames in the spinner. Defaults to empty,
      # @param final_text [String] Optional final string to display when the
      #     spinner is complete. Default is the empty string. A common practice
      #     is to set this to newline.
      # @return [Object] The return value of the block.
      #
      def spinner(leading_text: "", final_text: "",
                  frame_length: nil, frames: nil, style: nil, &block)
        terminal.spinner(leading_text: leading_text, final_text: final_text,
                         frame_length: frame_length, frames: frames, style: style,
                         &block)
      end

      on_initialize do |**opts|
        require "toys/utils/terminal"
        self[KEY] = Utils::Terminal.new(**opts)
      end
    end
  end
end
