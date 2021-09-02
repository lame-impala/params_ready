require_relative 'collection'

module ParamsReady
  module Marshaller
    class PolymorphMarshallers
      class StructMarshaller
        attr_reader :type_identifier

        def self.instance(type_identifier:)
          marshaller = new type_identifier
          marshaller.freeze
          [Hash, marshaller]
        end

        def initialize(type_identifier)
          @type_identifier = type_identifier.to_sym
        end

        def reserved?(name)
          name == type_identifier
        end

        def canonicalize(definition, hash, context, validator)
          raise ParamsReadyError, "Type key can't be retrieved" unless hash.length == 1
          key = hash.keys.first
          value = hash.values.first
          value = type(definition, key, value, context, validator)


          [value, validator]
        end

        def type(definition, key, value, context, validator)
          type_key = key.to_sym == type_identifier ? value : key
          prototype = definition.type(type_key, context)
          raise ParamsReadyError, "Unexpected type for #{definition.name}: #{type_key}" if prototype.nil?

          type = prototype.create
          return type if type_key == value
          type.set_from_input(value, context, validator)
          type
        end

        def marshal(parameter, intent)
          type = parameter.send(:bare_value)

          hash = type.to_hash_if_eligible(intent)
          return hash unless hash.nil?

          value = type.hash_key(intent)
          { type_identifier => value }
        end

        freeze
      end

      def self.collection
        @collection ||= begin
          c = ClassCollection.new Hash
          c.add_factory :hash, StructMarshaller
          c.freeze
          c
        end
      end
    end
  end
end
