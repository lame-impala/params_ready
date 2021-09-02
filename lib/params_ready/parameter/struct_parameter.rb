require_relative 'parameter'
require_relative '../builder'
require_relative 'abstract_struct_parameter'
require_relative '../marshaller/parameter_module'


module ParamsReady
  module Parameter
    class StructParameter < AbstractStructParameter
      include Marshaller::ParameterModule
    end

    class StructParameterBuilder < Builder
      include AbstractStructParameterBuilder::StructLike
      include Marshaller::BuilderModule
      register :struct
      register_deprecated :hash, use: :struct

      def self.instance(name, altn: nil)
        new StructParameterDefinition.new(name, altn: altn)
      end

      def map(hash)
        @definition.add_map(hash, **{})
      end
    end

    class StructParameterDefinition < AbstractStructParameterDefinition
      include Marshaller::DefinitionModule[Marshaller::StructMarshallers.collection]

      name_for_formatter :struct
      parameter_class StructParameter
      freeze_variables :key_map

      def ensure_canonical(hash)
        context = Format.instance(:backend)

        value, _validator = try_canonicalize hash, context, nil, freeze: true
        return value if value.length == hash.length

        extra_keys = hash.keys.select do |key|
          !value.key?(key)
        end.map do |key|
          "'#{key.to_s}'"
        end.join(", ")
        raise ParamsReadyError, "extra keys found -- #{extra_keys}" if extra_keys.length > 0
        value
      end


      def add_map(hash)
        @key_map ||= Helpers::KeyMap.new
        hash.each do |key, value|
          @key_map.map(key, to: value)
        end
      end

      def remap?(context)
        return false if key_map.nil?
        context.remap?
      end
    end
  end
end