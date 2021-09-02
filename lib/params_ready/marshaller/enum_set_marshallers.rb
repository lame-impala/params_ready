require_relative 'collection'
require_relative 'struct_marshallers'

module ParamsReady
  module Marshaller
    class EnumSetMarshallers
      module AbstractMarshaller
        def canonicalize_collection(definition, context, validator, freeze: false)
          hash = {}
          definition.names.each do |name, definition|
            child = definition.create
            value = yield child
            child.set_from_input(value, context, validator)
            child.freeze if freeze
            hash[name] = child
          end
          [hash, validator]
        end
      end

      module StructMarshaller
        extend AbstractMarshaller

        def self.canonicalize(definition, hash, context, validator)
          canonicalize_collection(definition, context, validator) do |child|
            _, value = child.find_in_hash(hash, context)
            value
          end
        end

        def self.marshal(parameter, intent)
          if intent.marshal? parameter.name_for_formatter
            StructMarshallers::StructMarshaller.marshal(parameter, intent)
          else
            SetMarshaller.marshal(parameter, intent)
          end
        end

        freeze
      end

      module SetMarshaller
        extend AbstractMarshaller

        def self.canonicalize(definition, set, context, validator, freeze: false)
          canonicalize_collection(definition, context, validator, freeze: freeze) do |child|
            value = definition.values[child.name]
            set.member?(value) || set.member?(value.to_s)
          end
        end

        def self.marshal(parameter, intent)
          intent = parameter.class.intent_for_set(intent)

          members = parameter.send(:bare_value).select do |_, m|
            m.unwrap_or(false) == true && m.eligible_for_output?(intent)
          end.map do |key, _|
            parameter.definition.values[key]
          end

          members.to_set
        end

        freeze
      end

      module ArrayMarshaller
        extend AbstractMarshaller

        def self.canonicalize(definition, array, context, validator)
          set = array.to_set
          SetMarshaller.canonicalize(definition, set, context, validator)
        end

        def self.marshal(parameter, intent)
          set = SetMarshaller.marshal(parameter, intent)
          set.to_a
        end

        freeze
      end

      def self.collection
        @collection ||= begin
          c = ClassCollection.new Hash
          c.add_instance Hash, StructMarshaller
          c.add_instance Set, SetMarshaller
          c.add_instance Array, ArrayMarshaller
          c.default!(Hash)
          c.freeze
          c
        end
      end
    end
  end
end
