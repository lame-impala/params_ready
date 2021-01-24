require_relative 'collection'
require_relative '../extensions/undefined'
require_relative '../extensions/hash'
require_relative '../helpers/find_in_hash'

module ParamsReady
  module Marshaller
    class ArrayMarshallers
      module AbstractMarshaller
        def marshal(parameter, intent)
          array = parameter.send(:bare_value)
          definition = parameter.definition
          compact = definition.compact?

          elements = array.map do |element|
            if element.eligible_for_output?(intent)
              element.format_self_permitted(intent)
            end
          end
          elements = elements.compact if compact
          do_marshal(elements, intent, compact)
        end
      end

      module ArrayMarshaller
        extend AbstractMarshaller

        def self.canonicalize(definition, array, context, validator, freeze: false)
          canonical = array.map do |value|
            next if definition.compact? && value.nil?

            element = definition.prototype.create
            element.set_from_input(value, context, validator)
            next if definition.compact? && element.is_nil?

            element.freeze if freeze
            element
          end.compact

          [canonical, validator]
        end

        def self.do_marshal(array, _, _)
          array
        end

        freeze
      end

      module HashMarshaller
        extend AbstractMarshaller

        def self.canonicalize(definition, hash, context, validator)
          if definition.compact?
            ArrayMarshaller.canonicalize(definition, hash.values, context, validator)
          else
            count_key = :cnt
            found, count = Helpers::FindInHash.find_in_hash hash, count_key
            raise ParamsReadyError, "Count not found" unless found

            count = Integer(count)
            array = (0...count).map do |index|
              found, value = Helpers::FindInHash.find_in_hash hash, index
              element = definition.prototype.create
              element.set_from_input(value, context, validator) if found
              element
            end
            [array, validator]
          end
        end

        def self.do_marshal(array, _, compact)
          return array if compact

          result = array.each_with_index.reduce({}) do |result, (element, index)|
            index = index.to_s
            result[index] = element
            result
          end

          result['cnt'] = array.length.to_s
          result
        end

        freeze
      end

      class StringMarshaller
        include AbstractMarshaller

        attr_reader :separator

        def self.instance(separator:, split_pattern: nil)
          instance = new separator, split_pattern
          [String, instance.freeze]
        end

        def initialize(separator, split_pattern)
          @separator = separator.to_s.freeze
          @split_pattern = split_pattern.freeze
        end

        def split_pattern
          @split_pattern || @separator
        end

        def canonicalize(definition, string, context, validator)
          array = string.split(split_pattern).map(&:strip).reject(&:empty?)
          ArrayMarshaller.canonicalize(definition, array, context, validator)
        end

        def do_marshal(array, _, _)
          array.join(separator)
        end

        freeze
      end

      def self.collection
        @collection ||= begin
          c = ClassCollection.new Array
          c.add_instance Array, ArrayMarshaller
          c.add_instance Hash, HashMarshaller
          c.add_factory :string, StringMarshaller
          c.default!(Hash)
          c.freeze
          c
        end
      end
    end
  end
end
