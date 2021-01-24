require_relative '../test_helper'
require_relative '../../lib/params_ready'

module ParamsReady
  module Examples
    class TupleExamples < Minitest::Test
      def test_tuple_example_works
        definition = Builder.define_tuple :pagination do
          field :integer, :offset do
            constrain :operator, :>=, 0, strategy: :clamp
          end
          field :integer, :limit do
            constrain :operator, :>=, 1, strategy: :clamp
          end
          marshal using: :string, separator: '-'
          default [0, 10]
        end
        _, parameter = definition.from_hash({ pagination: '2-20' })
        assert_equal '2-20', parameter.format(Format.instance(:frontend))
        end
    end
  end
end
