require_relative '../test_helper'
require_relative '../../lib/params_ready'

module ParamsReady
  module Examples
    class EnumSetExamples < Minitest::Test
      def test_basic_hash_set_example_works
        definition = Builder.define_enum_set :set do
          add :pending
          add :processing
          add :complete
        end
        _, parameter = definition.from_hash({ set: { pending: true, processing: true, complete: false }})
        assert_equal [:pending, :processing].to_set, parameter.unwrap
      end

      def test_hash_set_with_value_mapping_works
        definition = Builder.define_enum_set :set do
          add :pending, val: 0
          add :processing, val: 1
          add :complete, val: 2
        end
        _, parameter = definition.from_hash({ set: { pending: true, processing: true, complete: false }})
        assert_equal [0, 1].to_set, parameter.unwrap
      end
    end
  end
end
