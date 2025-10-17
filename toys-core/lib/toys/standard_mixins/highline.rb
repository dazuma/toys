# frozen_string_literal: true

module Toys
  module StandardMixins
    ##
    # A mixin that provides access to the capabilities of the highline gem.
    #
    # This mixin requires the highline gem, version 2.0 or later. It will
    # attempt to install the gem if it is not available.
    #
    # You may make these methods available to your tool by including the
    # following directive in your tool configuration:
    #
    #     include :highline
    #
    # A HighLine object will then be available by calling the {#highline}
    # method. For information on using this object, see the
    # [Highline documentation](https://www.rubydoc.info/gems/highline). Some of
    # the most common HighLine methods, such as `say`, are also mixed into the
    # tool and can be called directly.
    #
    # You can configure the HighLine object by passing options to the `include`
    # directive. For example:
    #
    #     include :highline, my_stdin, my_stdout
    #
    # The arguments will be passed on to the
    # [HighLine constructor](https://www.rubydoc.info/gems/highline/HighLine:initialize).
    #
    module Highline
      include Mixin

      ##
      # Context key for the highline object.
      # @return [Object]
      #
      KEY = ::Object.new.freeze

      ##
      # A tool-wide [HighLine](https://www.rubydoc.info/gems/highline/HighLine)
      # instance
      # @return [::HighLine]
      #
      def highline
        self[KEY]
      end

      ##
      # Calls [HighLine#agree](https://www.rubydoc.info/gems/highline/HighLine:agree)
      #
      def agree(...)
        self[KEY].agree(...)
      end

      ##
      # Calls [HighLine#ask](https://www.rubydoc.info/gems/highline/HighLine:ask)
      #
      def ask(...)
        self[KEY].ask(...)
      end

      ##
      # Calls [HighLine#choose](https://www.rubydoc.info/gems/highline/HighLine:choose)
      #
      def choose(...)
        self[KEY].choose(...)
      end

      ##
      # Calls [HighLine#list](https://www.rubydoc.info/gems/highline/HighLine:list)
      #
      def list(...)
        self[KEY].list(...)
      end

      ##
      # Calls [HighLine#say](https://www.rubydoc.info/gems/highline/HighLine:say)
      #
      def say(...)
        self[KEY].say(...)
      end

      ##
      # Calls [HighLine#indent](https://www.rubydoc.info/gems/highline/HighLine:indent)
      #
      def indent(...)
        self[KEY].indent(...)
      end

      ##
      # Calls [HighLine#newline](https://www.rubydoc.info/gems/highline/HighLine:newline)
      #
      def newline
        self[KEY].newline
      end

      ##
      # Calls [HighLine#puts](https://www.rubydoc.info/gems/highline/HighLine:puts)
      #
      def puts(*args)
        self[KEY].puts(*args)
      end

      ##
      # Calls [HighLine#color](https://www.rubydoc.info/gems/highline/HighLine:color)
      #
      def color(*args)
        self[KEY].color(*args)
      end

      ##
      # Calls [HighLine#color_code](https://www.rubydoc.info/gems/highline/HighLine:color_code)
      #
      def color_code(*args)
        self[KEY].color_code(*args)
      end

      ##
      # Calls [HighLine#uncolor](https://www.rubydoc.info/gems/highline/HighLine:uncolor)
      #
      def uncolor(*args)
        self[KEY].uncolor(*args)
      end

      ##
      # Calls [HighLine#new_scope](https://www.rubydoc.info/gems/highline/HighLine:new_scope)
      #
      def new_scope
        self[KEY].new_scope
      end

      on_initialize do |*args|
        require "toys/utils/gems"
        ::Toys::Utils::Gems.activate("highline", "~> 2.0")
        require "highline"
        self[KEY] = ::HighLine.new(*args)
        self[KEY].use_color = $stdout.tty?
      end
    end
  end
end
