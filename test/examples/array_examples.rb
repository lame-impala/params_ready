require_relative '../test_helper'
require_relative '../../lib/params_ready'

module ParamsReady
  module Examples
    class ArrayExamples < Minitest::Test
      def test_example_array_definition_is_legal
        post_ids = Builder.define_array :post_ids do
          prototype :integer, :post_id do
            default 5
          end
          default [1, 2, 3]
        end.create

        post_ids.set_value [4, 5]
        assert_equal [4, 5], post_ids.unwrap

        post_ids.set_value('1' => 7, '3' => 10, 'cnt' => 5)
        assert_equal [5, 7, 5, 10, 5], post_ids.unwrap
      end

      def test_compact_array_example_works
        definition = Builder.define_array :post_ids do
          prototype :integer, :post_id
          default [1, 2, 3]
          compact
        end
        _, post_ids = definition.from_input({ '5' => 3, 'bogus' => 2, 156440334 => 9 })
        assert_equal [3, 2, 9], post_ids.unwrap
      end

      def test_compact_array_with_nonzero_integer
        definition = Builder.define_array :nonzero_integers do
          prototype :value do
            coerce do |input, _|
              integer = Integer(input)
              next if integer == 0

              integer
            end

            format do |value, _|
              value.to_s
            end
            optional
          end
          compact
        end

        _, parameter = definition.from_input [0, 1, 0, 2]
        assert_equal [1, 2], parameter.unwrap
      end
    end
  end
end

