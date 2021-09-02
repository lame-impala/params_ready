require_relative '../test_helper'
require_relative '../../lib/params_ready/parameter/array_parameter'
require_relative '../../lib/params_ready/parameter/tuple_parameter'
require_relative '../../lib/params_ready/parameter/enum_set_parameter'
require_relative '../../lib/params_ready/format'
require_relative '../../lib/params_ready/query/polymorph_predicate'
require_relative '../../lib/params_ready/query/fixed_operator_predicate'

module ParamsReady
  module Marshaller
    class CustomMarshallersTest < Minitest::Test
      class Splitter
        def initialize(pattern)
          @pattern = pattern.freeze
          @length = pattern.sum
        end

        def canonicalize(definition, value, format, validator)
          raise ParamsReadyError, "Expected input length #{@length}, got: #{value.length}" unless @length == value.length

          chunks, _ = @pattern.reduce([ [], value ]) do |result, take|
            chunks = result[0]
            input = result[1]
            chunk, input = [input[0...take], input[take..-1]]
            chunks << chunk
            [chunks, input]
          end
          Marshaller::TupleMarshallers::ArrayMarshaller.canonicalize(definition, chunks, format, validator)
        end

        def marshal(parameter, _)
          array = parameter.send(:bare_value)
          array.map(&:unwrap).join('')
        end
      end

      def test_splitter_works
        d = Builder.define_tuple :splitter do
          field :string, :year
          field :string, :type
          field :string, :number
          marshal to: String, using: Splitter.new([2, 2, 8]).freeze
        end

        input = '20QN00000216'
        r, p = d.from_input input
        assert r.ok?, r.error
        assert_equal %w[20 QN 00000216], p.unwrap
        assert_equal input, p.format(Format.instance(:frontend))
      end

      class BinaryFlag
        def self.canonicalize(definition, value, format, validator)
          names = definition.names.keys
          raise ParamsReadyError, "Too many options: #{names}, max: #{32}" unless names.length <= 32
          hash, _ = names.each_with_object([{}, 1]) do |name, object|
            object[0][name] = (object[1] & value) > 0
            object[1] *=2
          end
          Marshaller::EnumSetMarshallers::StructMarshaller.canonicalize(definition, hash, format, validator)
        end

        def self.marshal(parameter, intent)
          names = parameter.names.keys
          raise ParamsReadyError, "Too many options: #{names}, max: #{32}" unless names.length <= 32

          result, _ = names.each_with_object([0, 1]) do |name, object|
            next unless parameter.eligible_for_output?(intent)

            object[0] |= object[1] if parameter[name].unwrap == true
            object[1] *=2
          end

          result
        end

        freeze
      end

      def test_binary_flag_works
        d = Builder.define_enum_set :binary_flag do
          add :good
          add :bad
          add :ugly
          marshal to: Integer, using: BinaryFlag
        end

        input = 0b101

        r, p = d.from_input input
        assert r.ok?, r.error
        assert_equal [:good, :ugly].to_set, p.unwrap
        assert_equal input, p.format(Format.instance(:frontend))
      end

      class StructToArray
        def initialize(identifier)
          @identifier = identifier.freeze
        end

        def canonicalize(definition, array, format, validator)
          hash = array.select do |hash|
            hash.key? @identifier
          end.compact.map do |hash|
            name = hash.dup.delete(@identifier)
            [name, hash]
          end.to_h
          Marshaller::StructMarshallers::StructMarshaller.canonicalize(definition, hash, format, validator)
        end

        def marshal(parameter, intent)
          hash = Marshaller::StructMarshallers::StructMarshaller.marshal(parameter, intent)
          hash.map do |key, value|
            value[@identifier] = key.to_s
            value
          end
        end
      end

      def test_array_to_hash_works
        d = Builder.define_struct :key_info do
          add :string, :key, altn: [:pk, :value]
          add :integer, :kid, altn: [:kid, :value]
          marshal to: Array, using: StructToArray.new('item').freeze
        end

        input = [{ 'item' => 'pk', value: 'abcd' }, { 'item' => 'kid', value: '23405' }]
        r, p = d.from_input input
        assert r.ok?, r.error
        assert_equal({ key: 'abcd', kid: 23405 }, p.unwrap)
        assert_equal input, p.format(Intent.instance(:frontend))
      end

      def test_remap_works_with_custom_hash_marshaller
        d = Builder.define_struct :remap do
          add :string, :key
          add :integer, :kid
          map [:pk, [:value]] => [[:key]]
          map [:kid, [:value]] => [[:kid]]
          marshal to: Array, using: StructToArray.new('item').freeze
        end

        input = [{ 'item' => 'pk', value: 'abcd' }, { 'item' => 'kid', value: 23405 }]
        context = InputContext.new(:json)
        r, p = d.from_input input, context: context
        assert r.ok?, r.error
        assert_equal({ key: 'abcd', kid: 23405 }, p.unwrap)
        assert_equal input, p.format(Intent.instance(:json))
      end

      class TypeInference
        ID_RE = /^\d+$/
        ACC_RE = /^\d\d[A-Z]{2}\d{8}$/

        HASH_MARSHALLER = PolymorphMarshallers::StructMarshaller.new :ppt

        def self.canonicalize(definition, string, context, validator)
          type, value = case string
          when ID_RE then[:id_eq, string]
          when ACC_RE then [:acc_eq, string]
          else [:ppt, nil]
          end
          HASH_MARSHALLER.canonicalize(definition, { type => value }, context, validator)
        end

        def self.marshal(parameter, intent)
          type = parameter.send(:bare_value)
          return nil unless type.eligible_for_output?(intent)

          type.unwrap.to_s
        end

        freeze
      end

      def test_type_inference_works
        d = Query::PolymorphPredicateBuilder.instance(:poly).include do
          type :fixed_operator_predicate, :id_eq, attr: :id do
            operator :equal
            type :value, :integer
          end
          type :fixed_operator_predicate, :acc_eq, attr: :accounting_id do
            operator :equal
            type :value, :string
          end
          marshal to: String, using: TypeInference
          optional
        end.build

        _, p = d.from_input('2107')
        assert_equal :id_eq, p.type
        assert_equal 2107, p[:id_eq].unwrap
        assert_equal 'subscriptions.id = 2107', p.to_query(Subscription.arel_table).to_sql.unquote

        _, p = d.from_input('20FT00033614')
        assert_equal :acc_eq, p.type
        assert_equal '20FT00033614', p[:acc_eq].unwrap
        assert_equal "subscriptions.accounting_id = '20FT00033614'", p.to_query(Subscription.arel_table).to_sql.unquote

        _, p = d.from_input('5FT01')
        assert_nil p.type
        assert_nil p.to_query_if_eligible(Subscription.arel_table, context: Restriction.blanket_permission)
      end
    end
  end
end