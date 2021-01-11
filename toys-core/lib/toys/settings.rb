# frozen_string_literal: true

module Toys
  ##
  # ## Extensible settings object
  #
  # A settings class defines the structure of application settings, i.e. the
  # various fields that can be set, and their types. You can define a settings
  # structure by subclassing this base class, and using the provided methods.
  #
  # ### Attributes
  #
  # To define an attribute, use the {Settings.settings_attr} declaration.
  #
  # Example:
  #
  #     class ServiceSettings < Toys::Settings
  #       settings_attr :endpoint, default: "api.example.com"
  #     end
  #
  #     my_settings = ServiceSettings.new
  #     my_settings.endpoint_set?   # => false
  #     my_settings.endpoint        # => "api.example.com"
  #     my_settings.endpoint = "rest.example.com"
  #     my_settings.endpoint_set?   # => true
  #     my_settings.endpoint        # => "rest.example.com"
  #     my_settings.endpoint_unset!
  #     my_settings.endpoint_set?   # => false
  #     my_settings.endpoint        # => "api.example.com"
  #
  # An attribute has a name, a default value, and a type specification. The
  # name is used to define methods for getting and setting the attribute. The
  # default is returned if no value is set. (See the section below on parents
  # and defaults for more information.) The type specification governs what
  # values are allowed. (See the section below on type specifications.)
  #
  # Attribute names must start with an ascii letter, and may contain only
  # letters, digits, and underscores. Additionally, the name `method_missing`
  # is not allowed because of its special behavior in Ruby.
  #
  # Each attribute defines four methods: a getter, a setter, an unsetter, and a
  # set detector. In the above example, the attribute named `:endpoint` creates
  # the following four methods:
  #
  #  *  `endpoint` - retrieves the attribute value, or a default if not set.
  #  *  `endpoint=(value)` - sets a new attribute value.
  #  *  `endpoint_unset!` - unsets the attribute, reverting to a default.
  #  *  `endpoint_set?` - returns a boolean, whether the attribute is set.
  #
  # ### Groups
  #
  # A group is a settings field that itself is a Settings object. You can use
  # it to group settings fields in a hierarchy.
  #
  # Example:
  #
  #     class ServiceSettings < Toys::Settings
  #       settings_attr :endpoint, default: "api.example.com"
  #       settings_group :service_flags do
  #         settings_attr :verbose, default: false
  #         settings_attr :use_proxy, default: false
  #       end
  #     end
  #
  #     my_settings = ServiceSettings.new
  #     my_settings.service_flags.verbose      # => false
  #     my_settings.service_flags.verbose = true
  #     my_settings.service_flags.verbose      # => true
  #     my_settings.endpoint                    # => "api.example.com"
  #
  # You can define a group inline, as in the example above, or create an
  # explicit settings class and use it for the group. For example:
  #
  #     class Flags < Toys::Settings
  #       settings_attr :verbose, default: false
  #       settings_attr :use_proxy, default: false
  #     end
  #     class ServiceSettings < Toys::Settings
  #       settings_attr :endpoint, default: "api.example.com"
  #       settings_group :service_flags, Flags
  #     end
  #
  #     my_settings = ServiceSettings.new
  #     my_settings.service_flags.verbose = true
  #
  # If the module enclosing a subclass of `Settings` is itself a subclass of
  # `Settings`, then the class is automatically added to its enclosing class as
  # a group. For example:
  #
  #     class ServiceSettings < Toys::Settings
  #       settings_attr :endpoint, default: "api.example.com"
  #       # Automatically adds this as the group service_flags.
  #       # The name is inferred (snake_cased) from the class name.
  #       class ServiceFlags < Toys::Settings
  #         settings_attr :verbose, default: false
  #         settings_attr :use_proxy, default: false
  #       end
  #     end
  #
  #     my_settings = ServiceSettings.new
  #     my_settings.service_flags.verbose = true
  #
  # ### Type specifications
  #
  # A type specification is a restriction on the types of values allowed for a
  # settings field. Every attribute has a type specification. You can set it
  # explicitly by providing a `:type` argument or a block. If a type
  # specification is not provided explicitly, it is inferred from the default
  # value of the attribute.
  #
  # Type specifications can be any of the following:
  #
  #  *  A Module, restricting values to those that include the module.
  #
  #     For example, a type specification of `Enumerable` would accept `[123]`
  #     but not `123`.
  #
  #  *  A Class, restricting values to that class or any subclass.
  #
  #     For example, a type specification of `Time` would accept `Time.now` but
  #     not `DateTime.now`.
  #
  #  *  A Regexp, restricting values to strings matching the regexp.
  #
  #     For example, a type specification of `/^\w+$/` would match `"abc"` but
  #     not `"abc!"`.
  #
  #  *  A Range, restricting values to objects that fall in the range and are
  #     of the same class (or a subclass) as the endpoints.
  #
  #     For example, a type specification of `(1..5)` would match `5` but not
  #     `6`.
  #
  #  *  A Symbol, String, Numeric, or the values `nil`, `true`, or `false`,
  #     restricting the value to only that given value.
  #
  #     For example, a type specification of `:foo` would match `:foo` but not
  #     `:bar`.
  #
  #     (It might not seem terribly useful to have an attribute that can take
  #     only one value, but this type is generally used in a union type,
  #     described below, to implement "enumerations".)
  #
  #  *  An Array representing a union type, each of whose elements is one of
  #     the above types. Values are accepted if they match any of the elements.
  #
  #     For example, a type specification of `[:a, :b :c]` would match `:a` but
  #     not `"a"`. Similarly, a type specification of `[String, Integer, nil]`
  #     would match `"hello"`, `123`, or `nil`, but not `123.4`.
  #
  #  *  A Proc that takes the proposed value and returns `true` or `false`
  #     indicating whether the value should be accepted. You may also pass a
  #     block to `settings_attr` to set a Proc type specification.
  #
  # If you do not explicitly provide a type specification, one is inferred from
  # the attribute's default value. The rules are:
  #
  #  *  If the default value is `true` or `false`, then the type specification
  #     inferred is `[true, false]`.
  #
  #  *  If the default value is `nil` or not provided, then the type
  #     specification allows any object (i.e. is equivalent to `Object`).
  #
  #  *  Otherwise, the type specification allows any value of the same class as
  #     the default value. For example, if the default value is `""`, the
  #     effective type specification is `String`.
  #
  # Examples:
  #
  #     class ServiceSettings < Toys::Settings
  #       # Allows only strings because the default is a string.
  #       settings_attr :endpoint, default: "example.com"
  #     end
  #
  #     class ServiceSettings < Toys::Settings
  #       # Allows strings or nil.
  #       settings_attr :endpoint, default: "example.com", type: [String, nil]
  #     end
  #
  #     class ServiceSettings < Toys::Settings
  #       # Raises ArgumentError because the default is nil, which does not
  #       # match the type specification.
  #       # (type: [String, nil] is probably intended here.)
  #       settings_attr :endpoint, type: String
  #     end
  #
  # ### Settings parents
  #
  # A settings object can have a "parent" which provides the values if they are
  # not set in the settings object. This lets you organize settings as
  # "defaults" and "overrides". A parent settings object provides the defaults,
  # and a child can selectively override certain values.
  #
  # To set the parent for a settings object, pass it as the argument to the
  # Settings constructor. When a field in a settings object is queried, it
  # looks up the value as follows:
  #
  #  *  If a field value is explicitly set in the settings object, that value
  #     is returned.
  #  *  If the field is not set in the settings object, but the settings object
  #     has a parent, the parent is queried. If that parent also does not have
  #     a value for the field, it may query its parent in turn, and so forth.
  #  *  If we encounter a root settings with no parent, and still no value is
  #     set for the field, the default is returned.
  #
  # Example:
  #
  #     class MySettings < Toys::Settings
  #       settings_attr :str, default: "default"
  #     end
  #
  #     root_settings = MySettings.new
  #     child_settings = MySettings.new(root_settings)
  #     child_settings.str        # => "default"
  #     root_settings.str = "value_from_root"
  #     child_settings.str        # => "value_from_root"
  #     child_settings.str = "value_from_child"
  #     child_settings.str        # => "value_from_child"
  #     child_settings.str_unset!
  #     child_settings.str        # => "value_from_root"
  #     root_settings.str_unset!
  #     child_settings.str        # => "default"
  #
  # Parents are honored through groups as well. For example:
  #
  #     class MySettings < Toys::Settings
  #       settings_group :flags do
  #         settings_attr :verbose, default: false
  #         settings_attr :force, default: false
  #       end
  #     end
  #
  #     root_settings = MySettings.new
  #     child_settings = MySettings.new(root_settings)
  #     child_settings.flags.verbose       # => false
  #     root_settings.flags.verbose = true
  #     child_settings.flags.verbose       # => true
  #
  # Usually, a settings and its parent (and its parent, and so forth) should
  # have the same class. This guarantees that they define the same fields.
  # However, this is not required. If a parent does not define a particular
  # field, it is treated as if that field is unset, and lookup proceeds to its
  # parent. To illustrate:
  #
  #     class Settings1 < Toys::Settings
  #       settings_attr :str, default: "default"
  #     end
  #     class Settings2 < Toys::Settings
  #     end
  #
  #     root_settings = Settings1.new
  #     child_settings = Settings2.new(root_settings)  # does not have str
  #     grandchild_settings = Settings1.new(child_settings)
  #
  #     grandchild_settings.str        # => "default"
  #     root_settings.str = "value_from_root"
  #     grandchild_settings.str        # => "value_from_root"
  #
  # Type specifications are enforced when falling back to parent values. If a
  # parent provides a value that is not allowed, it is treated as if the field
  # is unset, and lookup proceeds to its parent.
  #
  #     class Settings1 < Toys::Settings
  #       settings_attr :str, default: "default"  # type spec is String
  #     end
  #     class Settings2 < Toys::Settings
  #       settings_attr :str, default: 0  # type spec is Integer
  #     end
  #
  #     root_settings = Settings1.new
  #     child_settings = Settings2.new(root_settings)
  #     grandchild_settings = Settings1.new(child_settings)
  #
  #     grandchild_settings.str        # => "default"
  #     child_settings.str = 123       # does not match grandchild's type
  #     root_settings.str = "value_from_root"
  #     grandchild_settings.str        # => "value_from_root"
  #
  class Settings
    # @private
    DEFAULT_TYPE = ::Object.new.freeze

    # @private
    CONFIG_MATCHER = proc { |val| val.nil? || val.is_a?(Settings) }

    ##
    # Create a settings instance.
    #
    # @param parent [Settings,nil] Optional parent settings.
    #
    def initialize(parent = nil)
      @parent = parent.is_a?(Settings) ? parent : nil
      @mutex = ::Mutex.new
      @values = ::Hash.new
    end

    ##
    # @private
    # Internal get field value, with fallback to parents.
    #
    # @param name [Symbol] The field name.
    # @param matcher [Proc] Type checking function.
    # @param default [Object] Default value if the field is not set in this
    #     settings object or any of its ancestors.
    # @return [Object] value
    #
    def get!(name, matcher, default)
      @mutex.synchronize do
        if @values.key?(name)
          val = @values[name]
          return val if matcher.call(val)
        end
      end
      return @parent.get!(name, matcher, default) if @parent
      default
    end

    class << self
      ##
      # Add an attribute field.
      #
      # @param name [Symbol,String] The name of the attribute.
      # @param default [Object] Optional. The final default value if the field
      #     is not set in this settings object or any of its ancestors. If not
      #     provided, `nil` is used.
      # @param type [Object] Optional. The type specification. If not provided,
      #     one is inferred from the default value.
      #
      def settings_attr(name, default: nil, type: DEFAULT_TYPE, &block)
        name = interpret_name(name)
        type = block if type == DEFAULT_TYPE && block
        type = default_type_spec(default) if type == DEFAULT_TYPE
        matcher, type_str = interpret_type_spec(type)
        unless matcher.call(default)
          raise ::ArgumentError,
                "Default value #{default.inspect} does not match type #{type_str}" \
                " for settings field #{name}"
        end
        create_getter(name, matcher, default)
        create_setter(name, matcher, type_str)
        create_set_detect(name)
        create_unsetter(name)
        self
      end

      ##
      # Add a group field.
      #
      # Specify the group's structure by passing either a class (which must
      # subclass Settings) or a block (which will be called on the group's
      # class.)
      #
      # @param name [Symbol, String] The name of the group.
      # @param klass [Class] Optional. The class of the group (which must
      #     subclass Settings). If not present, an anonymous subclass will be
      #     created, and you must provide a block to configure it.
      #
      def settings_group(name, klass = nil, &block)
        name = interpret_name(name)
        if klass.nil? == block.nil?
          raise ::ArgumentError, "A group field requires a class or a block, but not both."
        end
        unless klass
          klass = ::Class.new(Settings)
          klass.class_eval(&block)
        end
        create_group_getter(name, klass)
        self
      end

      ##
      # @private
      # When this base class is inherited, if its enclosing module is also a
      # Settings, add the new class as a group in the enclosing class.
      #
      def inherited(subclass)
        path = subclass.name.to_s.split("::")
        namespace = path[0...-1].reduce(::Object) { |mod, name| mod.const_get(name.to_sym) }
        if namespace.ancestors.include?(Settings)
          name = to_field_name(path.last)
          namespace.settings_group(name, subclass)
        end
      end

      private

      def to_field_name(str)
        str = str.to_s.sub(/^_/, "").sub(/_$/, "").gsub(/_+/, "_")
        while str.sub!(/([^_])([A-Z])/, "\\1_\\2") do end
        str.downcase
      end

      def interpret_name(name)
        name = name.to_s
        if name !~ /^[a-zA-Z]\w*$/ || name == "method_missing"
          raise ::ArgumentError, "Illegal settings field name: #{name}"
        end
        existing = public_instance_methods(false)
        if existing.include?(name.to_sym) || existing.include?("#{name}=".to_sym) ||
           existing.include?("#{name}_set?".to_sym) || existing.include?("#{name}_unset!".to_sym)
          raise ::ArgumentError, "Settings field already exists: #{name}"
        end
        name.to_sym
      end

      def default_type_spec(default)
        case default
        when nil
          Object
        when true, false
          [true, false]
        else
          default.class
        end
      end

      def interpret_type_spec(type)
        case type
        when ::Module
          interpret_module_type(type)
        when ::Range
          interpret_range_type(type)
        when ::Regexp
          interpret_regexp_type(type)
        when ::Array
          interpret_union_type(type)
        when nil, true, false, ::String, ::Symbol, ::Numeric
          interpret_scalar_type(type)
        when ::Proc
          [type, "(opaque function)"]
        else
          raise ::ArgumentError, "Illegal type spec: #{type.inspect}"
        end
      end

      def interpret_module_type(klass)
        [
          proc { |val| val.is_a?(klass) },
          klass.to_s,
        ]
      end

      def interpret_range_type(range)
        range_class = (range.begin || range.end).class
        [
          proc { |val| val.is_a?(range_class) && range.member?(val) },
          "(#{range})",
        ]
      end

      def interpret_regexp_type(regexp)
        [
          proc { |val| regexp === val },
          "/#{regexp.source.gsub('/', '\\/')}/",
        ]
      end

      def interpret_union_type(array)
        type_info = array.map { |elem| interpret_type_spec(elem) }
        matchers = type_info.map(&:first)
        [
          proc { |val| matchers.any? { |elem| elem.call(val) } },
          "[#{type_info.map(&:last).join(', ')}]",
        ]
      end

      def interpret_scalar_type(value)
        [
          proc { |val| val == value },
          value.inspect,
        ]
      end

      def create_getter(name, matcher, default)
        define_method(name) do
          get!(name, matcher, default)
        end
      end

      def create_setter(name, matcher, type_str)
        define_method("#{name}=") do |val|
          unless matcher.call(val)
            raise ::ArgumentError,
                  "Value #{val.inspect} does not match type #{type_str} for settings field #{name}"
          end
          @mutex.synchronize do
            @values[name] = val
          end
        end
      end

      def create_set_detect(name)
        define_method("#{name}_set?") do
          @mutex.synchronize do
            @values.key?(name)
          end
        end
      end

      def create_unsetter(name)
        define_method("#{name}_unset!") do
          @mutex.synchronize do
            @values.delete(name)
          end
        end
      end

      def create_group_getter(name, klass)
        define_method(name) do
          @mutex.synchronize do
            if @values.key?(name)
              @values[name]
            else
              parent = @parent ? @parent.get!(name, CONFIG_MATCHER, nil) : nil
              @values[name] = klass.new(parent)
            end
          end
        end
      end
    end
  end
end
