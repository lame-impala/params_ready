require_relative 'parameter'
require_relative '../value/validator'
require_relative '../value/coder'
require_relative 'definition'
require_relative '../builder'

module ParamsReady
  module Parameter
    class ValueParameter < Parameter
      def_delegators :@definition, :coder

      def marshal(intent)
        return nil if is_nil?

        value = bare_value
        return value unless intent.marshal?(name_for_formatter)

        coder.format(value, intent)
      end

      protected

      def update_self(value)
        clone = dup
        clone.set_value value

        if frozen?
          if clone == self
            return false, self
          else
            [true, clone.freeze]
          end
        else
          [true, clone]
        end
      end

      def populate_with(value)
        @value = value.dup
      end
    end

    class ValueParameterBuilder < Builder
      module ValueLike
        def constrain(name_or_constraint, *args, strategy: :raise, **opts, &block)
          validator = Value::Validator.instance(name_or_constraint, *args, strategy: strategy, **opts, &block)
          @definition.add_constraint validator
        end

        def coerce(&block)
          @definition.set_coerce(block)
        end

        def format(&block)
          @definition.set_format(block)
        end

        def type_identifier(name)
          @definition.set_type_identifier(name)
        end
      end

      include ValueLike
      extend Extensions::Registry

      register :value

      registry :coders, as: :coder, getter: true do |name, _|
        builder_class = ValueParameterBuilder[name]
        builder_class.register name
      end

      def self.instance(name, coder_or_name = nil, altn: nil)
        coder = if coder_or_name.is_a? Symbol
          self.coder(coder_or_name)
        elsif coder_or_name.nil?
          Value::GenericCoder.new(name)
        else
          coder_or_name
        end
        new ValueParameterDefinition.new(name, coder, altn: altn)
      end

      def self.[](type)
        builder = Class.new(self)
        capitalized = type.to_s.split('_').map(&:capitalize).join
        qualified = "#{self.name}::#{capitalized}Builder".freeze

        builder.define_singleton_method :name do
          qualified
        end

        builder.define_singleton_method :instance do |name, altn: nil|
          superclass.instance(name, type, altn: altn)
        end

        builder
      end

      register_coder :integer, Value::IntegerCoder
      register_coder :decimal, Value::DecimalCoder
      register_coder :string, Value::StringCoder
      register_coder :symbol, Value::SymbolCoder
      register_coder :boolean, Value::BooleanCoder
      register_coder :date, Value::DateCoder
      register_coder :datetime, Value::DateTimeCoder
    end

    class ValueParameterDefinition < Definition
      extend Forwardable
      def_delegators :@coder, :set_coerce, :set_format, :set_type_identifier

      name_for_formatter :value

      def name_for_formatter
        coder_name = @coder.type_identifier
        return coder_name unless coder_name.nil?

        super
      end

      parameter_class ValueParameter

      module ValueLike
        def duplicate_value(value)
          value.dup
        end

        def freeze_value(value)
          value.freeze
        end
      end

      include ValueLike

      attr_reader :coder

      collection :constraints, :constraint do |constraint|
        raise ParamsReadyError, "Can't constrain after default has been set" if default_defined?
        constraint
      end

      def initialize(name, coder, *args, constraints: [], **options)
        @coder = coder
        @constraints = constraints
        super name, *args, **options
      end

      def try_canonicalize(input, context, validator = nil)
        value = coder.try_coerce input, context
        return value if Extensions::Undefined.value_indefinite?(value)

        value, validator = validate value, validator
        if validator.nil? || validator.ok?
          [value.freeze, validator]
        else
          [nil, validator]
        end
      end

      def ensure_canonical(value)
        coerced = coder.try_coerce value, Format.instance(:backend)
        if coder.strict_default? && value != coerced
          raise ParamsReadyError, "input '#{value}' (#{value.class.name}) coerced to '#{coerced}' (#{coerced.class.name})"
        end
        validate coerced
        coerced
      end

      def validate(value, validator = nil)
        constraints.reduce([value, validator]) do |(value, validator), constraint|
          constraint.validate value, validator
        end
      end

      def finish
        @coder.finish if @coder.respond_to?(:finish)
        super
      end
    end
  end
end
