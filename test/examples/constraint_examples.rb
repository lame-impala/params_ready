require_relative '../test_helper'
require_relative '../../lib/params_ready'

module ParamsReady
  module Examples
    class ConstraintExamples < Minitest::Test
      def test_range_example_is_legal
        range = Builder.define_integer(:range) do
          constrain :range, (1..5)
        end.create

        range.set_value 2

        assert_raises(Value::Constraint::Error) do
          range.set_value 17
        end
      end

      def test_enum_example_with_array_is_legal
        enum = Builder.define_string(:enum) do
          constrain :enum, %w[foo bar]
        end.create

        enum.set_value 'foo'

        assert_raises(Value::Constraint::Error) do
          enum.set_value 'baz'
        end
      end

      def test_constraint_raises_constraint_error_with_invalid_input
        non_negative = Builder.define_integer(:non_negative) do
          constrain :operator, :>=, 0
        end.create

        assert_raises(Value::Constraint::Error) do
          non_negative.set_value -5
        end
      end

      def test_clamping_constraint_works
        d = Builder.define_integer(:param) do
          constrain :range, (1..5), strategy: :clamp
        end

        r, p = d.from_input 6
        assert r.ok?
        assert_equal 5, p.unwrap

        r, p = d.from_input 0
        assert r.ok?
        assert_equal 1, p.unwrap
      end
    end
  end
end
