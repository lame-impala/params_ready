require 'json'
require 'base64'
require_relative 'collection'

module ParamsReady
  module Marshaller
    class StructMarshallers
      module AbstractMarshaller
        def extract_bare_value(parameter, intent)
          parameter.names.keys.reduce({}) do |result, name|
            c = parameter[name]
            hash = c.to_hash_if_eligible(intent)
            if hash.nil?
              result
            else
              result.deep_merge(hash)
            end
          end
        end
      end

      module Base64Marshaller
        def self.instance
          [String, self]
        end

        def self.canonicalize(definition, string, context, validator)
          json = Base64.urlsafe_decode64(string)
          hash = JSON.parse(json)
          StructMarshaller.canonicalize(definition, hash, context, validator)
        end

        def self.marshal(parameter, intent)
          hash = StructMarshaller.marshal(parameter, intent)
          json = JSON.generate(hash)
          Base64.urlsafe_encode64(json)
        end

        freeze
      end

      module StructMarshaller
        extend AbstractMarshaller

        def self.canonicalize(definition, hash, context, validator, freeze: false)
          hash = if definition.respond_to?(:remap?) && definition.remap?(context)
            definition.key_map.to_standard(hash)
          else
            hash
          end

          value = definition.names.each_with_object({}) do |(name, child_def), result|
            child = child_def.create
            child.set_from_hash(hash, validator: validator&.for_child(name), context: context)
            child.freeze if freeze
            result[name] = child
          end
          [value, validator]
        end

        def self.marshal(parameter, intent)
          value = extract_bare_value(parameter, intent)

          definition = parameter.definition

          if value == {}
            if intent.marshal?(definition.name_for_formatter)
              if definition.optional? || definition.default_defined?
                parameter.class::EMPTY_HASH
              elsif intent.omit?(parameter)
                nil
              else
                value
              end
            else
              value
            end
          elsif definition.respond_to?(:remap?) && definition.remap?(intent)
            definition.key_map.to_alternative(value)
          else
            value
          end
        end

        freeze
      end

      def self.collection
        @collection ||= begin
          c = ClassCollection.new Hash
          c.add_instance Hash, StructMarshaller
          c.add_factory :base64, Base64Marshaller
          c.default!(Hash)
          c.freeze
          c
        end
      end
    end
  end
end
