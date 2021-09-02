require_relative 'collection'
require_relative '../extensions/undefined'
require_relative '../extensions/hash'

module ParamsReady
  module Marshaller
    class TupleMarshallers
      module AbstractMarshaller
        def self.marshal_fields(fields, intent)
          fields.map do |field|
            field.format(intent)
          end
        end

        def marshal(parameter, intent)
          fields = parameter.send(:bare_value)
          fields = AbstractMarshaller.marshal_fields(fields, intent)
          do_marshal(fields, intent)
        end
      end

      module ArrayMarshaller
        extend AbstractMarshaller

        def self.canonicalize(definition, array, context, validator, freeze: false)
          if array.length != definition.arity
            raise ParamsReadyError, "Unexpected array length: #{array.length}"
          end

          canonical = definition.fields.each_with_index.map do |field_definition, index|
            element = field_definition.create
            element.set_from_input(array[index], context, validator)
            element.freeze if freeze
            element
          end
          [canonical, validator]
        end

        def self.do_marshal(fields, _)
          fields
        end

        freeze
      end

      module StructMarshaller
        extend AbstractMarshaller

        def self.canonicalize(definition, hash, context, validator)
          array = (0...definition.arity).map do |idx|
            Extensions::Hash.indifferent_access(hash, idx, Extensions::Undefined)
          end
          ArrayMarshaller.canonicalize(definition, array, context, validator)
        end

        def self.do_marshal(fields, _)
          fields.each_with_index.map do |field, index|
            [index.to_s, field]
          end.to_h
        end

        freeze
      end

      class StringMarshaller
        include AbstractMarshaller

        attr_reader :separator

        def self.instance(separator:)
          instance = new separator
          [String, instance.freeze]
        end

        def initialize(separator)
          @separator = separator.to_s.freeze
        end

        def canonicalize(definition, string, context, validator)
          array = string.split(separator)
          ArrayMarshaller.canonicalize(definition, array, context, validator)
        end

        def do_marshal(fields, _)
          fields.join(separator)
        end

        freeze
      end

      def self.collection
        @collection ||= begin
          c = ClassCollection.new Array
          c.add_instance Array, ArrayMarshaller
          c.add_instance Hash, StructMarshaller
          c.add_factory :string, StringMarshaller
          c.freeze
          c
        end
      end
    end
  end
end
