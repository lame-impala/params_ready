require 'set'
require_relative 'parameter'
require_relative '../builder'
require_relative 'definition'
require_relative 'array_parameter'
require_relative '../marshaller/tuple_marshallers'
require_relative '../marshaller/definition_module'
require_relative '../marshaller/builder_module'
require_relative '../marshaller/parameter_module'

module ParamsReady
  module Parameter
    class TupleParameter < Parameter
      include ArrayParameter::ArrayLike
      include Marshaller::ParameterModule

      def_delegators :@definition, :names, :fields, :separator, :marshaller

      freeze_variable :value do |array|
        next if Extensions::Undefined.value_indefinite?(array)
        array.each(&:freeze)
      end

      def method_missing(name, *args)
        integer = ordinal_to_integer(name)
        if integer.nil?
          super
        else
          self[integer - 1]
        end
      end

      def respond_to_missing?(name, include_private = false)
        return true unless ordinal_to_integer(name).nil?
        super
      end

      protected

      def element(index)
        return nil if is_nil?

        value = bare_value
        if index < 0 || index >= value.length
          raise ParamsReadyError, "Index out of bounds: #{index}"
        else
          value[index]
        end
      end

      ORDINALS = %i{
        first second third fourth fifth sixth seventh eighth nineth tenth
      }.each_with_index.map do |ordinal, index|
        [ordinal, index + 1]
      end.to_h.freeze

      def ordinal_to_integer(name)
        integer = ORDINALS[name]
        return nil if integer.nil?
        return nil if definition.arity < integer

        integer
      end

      def init_value
        @value = []
        fields.each do |definition|
          @value << definition.create
        end
      end
    end

    class TupleParameterBuilder < Builder
      include Marshaller::BuilderModule
      register :tuple

      def self.instance(name, altn: nil)
        new TupleParameterDefinition.new(name, altn: altn)
      end

      def field(input, *args, **opts, &block)
        definition = self.class.resolve(input, *args, **opts, &block)
        @definition.add_field definition
      end
    end

    class TupleParameterDefinition < Definition
      include ArrayParameterDefinition::ArrayLike
      include Marshaller::DefinitionModule[Marshaller::TupleMarshallers.collection]

      class StringMarshaller
        def initialize(separator:)
          @separator = separator
        end

        def marshal(fields, _format)
          fields.join(@separator)
        end
      end

      class HashMarshaller
        def marshal(fields, _format)
          fields.each_with_index.map do |field, index|
            [index.to_s, field]
          end.to_h
        end
      end

      name_for_formatter :tuple

      parameter_class TupleParameter

      def initialize(*args, separator: nil, fields: nil, **options)
        @fields = []
        add_fields fields unless fields.nil?
        super *args, **options
      end

      def add_fields(fields)
        fields.each do |field|
          add_field(field)
        end
      end

      collection :fields, :field do |field|
        raise ParamsReadyError, "Can't add field if default is present" if default_defined?
        raise ParamsReadyError, "Not a field definition #{field.class.name}" unless field.is_a? AbstractDefinition
        raise ParamsReadyError, "Field is not a value #{field.class.name}" unless field.is_a? ValueParameterDefinition
        raise ParamsReadyError, "Field can't be optional" if field.optional?
        raise ParamsReadyError, "Field can't have default" if field.default_defined?
        field
      end

      def arity
        @fields.length
      end

      def ensure_canonical(array)
        raise ParamsReadyError, "Not an array" unless array.is_a? Array
        context = Format.instance(:backend)
        marshaller = marshallers.instance(Array)
        value, _validator = marshaller.canonicalize(self, array, context, nil, freeze: true)
        value
      end

      def freeze
        @fields.freeze
        super
      end
    end
  end
end
