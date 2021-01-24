require_relative 'parameter'
require_relative '../builder'
require_relative 'abstract_hash_parameter'
require_relative '../marshaller/parameter_module'


module ParamsReady
  module Parameter
    class HashParameter < AbstractHashParameter
      include Marshaller::ParameterModule
    end

    class HashParameterBuilder < Builder
      include AbstractHashParameterBuilder::HashLike
      include Marshaller::BuilderModule
      register :hash

      def self.instance(name, altn: nil)
        new HashParameterDefinition.new(name, altn: altn)
      end

      def map(hash)
        @definition.add_map(hash, **{})
      end
    end

    class HashParameterDefinition < AbstractHashParameterDefinition
      include Marshaller::DefinitionModule[Marshaller::HashMarshallers.collection]

      name_for_formatter :hash
      parameter_class HashParameter
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