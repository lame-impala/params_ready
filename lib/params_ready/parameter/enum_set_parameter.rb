require 'set'
require_relative 'struct_parameter'
require_relative 'value_parameter'
require_relative '../intent'
require_relative '../marshaller/enum_set_marshallers'
require_relative '../marshaller/parameter_module'

module ParamsReady
  module Parameter
    class EnumSetParameter < AbstractStructParameter
      include Marshaller::ParameterModule

      def self.intent_for_set(intent)
        Intent.new(
          intent.format.update(
            omit: [],
            remap: false
          ),
          intent.restriction
        )
      end

      def member?(key)
        raise ParamsReadyError, "Key not defined: '#{key}'" unless definition.has_child? key

        if is_definite?
          bare_value[key].unwrap == true
        else
          false
        end
      end
    end

    class EnumSetParameterBuilder < Builder
      include Marshaller::BuilderModule

      register :enum_set
      register_deprecated :hash_set, use: :enum_set

      def self.instance(name, altn: nil, type: :boolean)
        new EnumSetParameterDefinition.new(name, altn: altn, type: type)
      end

      def add(input, *args, val: nil, **opts, &block)
        type = @definition.type
        definition = self.class.resolve(type, input, *args, **opts, &block)
        @definition.add_child definition, value: val
      end


      def self.resolve(type, input, *args, **opts, &block)
        if input.is_a? AbstractDefinition
          input
        else
          define_registered_parameter(type, input, *args, **opts, &block)
        end
      end
    end

    class EnumSetParameterDefinition < AbstractStructParameterDefinition
      attr_reader :type, :values
      freeze_variable :values
      name_for_formatter :enum_set
      parameter_class EnumSetParameter
      include Marshaller::DefinitionModule[Marshaller::EnumSetMarshallers.collection]

      def initialize(*args, type: :boolean, **opts)
        @type = type
        @values = {}
        super *args, **opts
      end

      def ensure_canonical(set)
        raise ParamsReadyError, "Unexpected default type: #{set.class.name}" unless set.is_a?(Set)

        context = Format.instance(:backend)
        value, _validator = try_canonicalize set, context, nil, freeze: true
        return value if value.length == set.length

        extra_keys = set.reject do |key|
          value.key?(key) || value.key?(key.to_s)
        end.map do |key|
          "'#{key.to_s}'"
        end.join(", ")
        raise ParamsReadyError, "extra elements found -- #{extra_keys}" if extra_keys.length > 0

        value
      end

      def add_child(child, value:)
        value = value.nil? ? child.name : value

        if @values.key(value).nil?
          @values[child.name] = value
        else
          raise ParamsReadyError, "Value '#{value}' already taken by '#{@values.key(value)}'"
        end
        super child
      end
    end
  end
end