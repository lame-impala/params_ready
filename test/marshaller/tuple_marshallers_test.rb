require_relative '../test_helper'
require_relative '../../lib/params_ready/marshaller/tuple_marshallers'
require_relative '../../lib/params_ready/parameter/tuple_parameter'
require_relative '../../lib/params_ready/format'

module ParamsReady
  module Marshaller
    class TupleMarshallersTest < Minitest::Test
      def get_def
        Builder.define_tuple :test do
          field :integer, :num
          field :symbol, :str
          marshal using: :string, separator: '-'
        end
      end

      def test_array_marshaller_canonicalizes_correct_array
        d = get_def
        input = %w[5 foo]
        ic = TupleMarshallers.collection.instance_collection
        result, _ = ic.canonicalize(d, input, :context, nil)
        assert_equal [5, :foo], result.map(&:unwrap)
      end

      def test_array_marshaller_marshals_into_array
        _, p = get_def.from_input([5, :foo])
        value = p.send(:bare_value)
        ic = TupleMarshallers.collection.instance_collection
        ic.default = ic.instance(Array)
        param = Minitest::Mock.new
        param.expect(:bare_value, value)
        result = ic.marshal(param, Format.instance(:frontend))
        assert_equal %w[5 foo], result
      end

      def test_array_marshaller_freezes_elements_if_asked_to
        d = get_def
        input = %w[5 foo]
        ic = TupleMarshallers.collection.instance_collection
        result, _ = ic.canonicalize(d, input, :context, nil, freeze: true)
        assert result[0].frozen?
        assert result[1].frozen?
      end

      def test_array_marshaller_checks_for_arity
        d = get_def
        input = %w[5 foo bar]
        err = assert_raises do
          ic = TupleMarshallers.collection.instance_collection
          ic.canonicalize(d, input, :context, nil)
        end
        assert_equal 'Unexpected array length: 3', err.message
      end

      def test_hash_marshaller_canonicalizes_correct_hash
        d = get_def
        input = { '0' => '5', 1 => 'foo' }
        ic = TupleMarshallers.collection.instance_collection
        result, _ = ic.canonicalize(d, input, :context, nil)
        assert_equal [5, :foo], result.map(&:unwrap)
      end

      def test_array_marshaller_marshals_into_hash
        _, p = get_def.from_input([5, :foo])
        value = p.send(:bare_value)
        ic = TupleMarshallers.collection.instance_collection
        ic.default = ic.instance(Hash)

        param = Minitest::Mock.new
        param.expect(:bare_value, value)
        result = ic.marshal(param, Format.instance(:frontend))
        assert_equal({ '0' => '5', '1' => 'foo' }, result)
      end

      def test_string_marshaller_canonicalizes_correct_string
        d = get_def
        input = '5-foo'
        ic = TupleMarshallers.collection.instance_collection
        ic.add_instance(*TupleMarshallers.collection.build_instance(:string, separator: '-'))
        result, _ = ic.canonicalize(d, input, :context, nil)
        assert_equal [5, :foo], result.map(&:unwrap)
      end

      def test_string_marshaller_marshals_into_string
        _, p = get_def.from_input([5, :foo])
        value = p.send(:bare_value)

        ic = TupleMarshallers.collection.instance_collection
        ic.add_instance(*TupleMarshallers.collection.build_instance(:string, separator: '-'))
        ic.default!(String)

        param = Minitest::Mock.new
        param.expect(:bare_value, value)
        result = ic.marshal(param, Format.instance(:frontend))
        assert_equal '5-foo', result
      end
    end
  end
end