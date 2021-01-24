require_relative '../test_helper'
require_relative '../context_using_parameter_helper'
require_relative '../../lib/params_ready/parameter/value_parameter'
require_relative '../../lib/params_ready/input_context'
require_relative '../../lib/params_ready/intent'

module ParamsReady
  module Parameter
    class ValueParameterTest < Minitest::Test
      def get_def(type, name, altn, default: Extensions::Undefined, optional: false, constraints: [])
        Builder.send "define_#{type}", name, altn: altn do
          constraints.each do |c|
            constrain c
          end
          default(default) unless default == Extensions::Undefined
          self.optional if optional
        end
      end

      def test_match_returns_true_if_definition_is_identical
        d1 = get_def :string, :parameter, :prm
        d2 = get_def :string, :parameter, :prm
        p1a = d1.create
        p1b = d1.create
        p2 = d2.create
        assert p1a.match?(p1b)
        refute p2.match?(p1b)
        refute p1b.match?(p2)
      end

      def test_only_matching_parameters_equal
        d1 = get_def :string, :parameter, :prm
        d2 = get_def :string, :parameter, :prm
        p1a = d1.create
        p1b = d1.create
        p2 = d2.create
        refute_equal p1a, p1b
        refute_equal p1a, p2
        refute_equal p2, p1b
        p1a.set_value "another"
        p1b.set_value "other"
        p2.set_value "other"
        refute_equal p1a, p1b
        refute_equal p1a, p2
        refute_equal p2, p1b
        p1a.set_value "some"
        p1b.set_value "some"
        p2.set_value "some"
        assert_equal p1a, p1b
        refute_equal p1a, p2
      end
    end

    class ValueParameterConstraintTest < Minitest::Test
      class EvenConstraint
        def self.valid?(value)
          value % 2 == 0
        end

        def self.error_message
          'is not even'
        end
      end

      def test_custom_constraint_works
        d = Builder.define_integer(:even) do
          constrain EvenConstraint
        end
        _, p = d.from_input 4
        assert_equal 4, p.unwrap
        r, _ = d.from_input 5
        refute r.ok?
        assert_equal "errors for even -- value '5' is not even", r.error.message
      end

      def test_undefine_constraint_works_with_optional
        d = Builder.define_integer(:param) do
          constrain :range, (1..5), strategy: :undefine
          optional
        end

        _, p = d.from_input 5
        assert_equal 5, p.unwrap

        r, p = d.from_input 6

        assert r.ok?
        assert p.is_undefined?
      end

      def test_undefine_constraint_works_with_default
        d = Builder.define_integer(:param) do
          constrain :range, (1..5), strategy: :undefine
          default 3
        end

        _, p = d.from_input 5
        assert_equal 5, p.unwrap

        r, p = d.from_input 6

        assert r.ok?
        assert_equal 3, p.unwrap
      end

      def test_undefine_constraint_raises_with_non_optional_and_no_default
        d = Builder.define_integer(:param) do
          constrain :range, (1..5), strategy: :undefine
        end

        _, p = d.from_input 5
        assert_equal 5, p.unwrap

        err = assert_raises(ValueMissingError) do
          _, p = d.from_input 6
          p.unwrap
        end

        assert_equal 'param: value is nil', err.message
      end

      def test_update_in_with_invalid_value_and_undefine_constraint_sets_default_having_parameter_to_default
        d = Builder.define_integer(:param) do
          constrain :range, (1..5), strategy: :undefine
          default 3
        end

        _, p = d.from_input 5
        assert_equal 5, p.unwrap

        p.freeze
        u = p.update_in(6, [])
        assert_equal 3, u.unwrap
      end

      def test_update_in_with_invalid_value_and_undefine_constraint_sets_optional_parameter_to_undefined
        d = Builder.define_integer(:param) do
          constrain :range, (1..5), strategy: :undefine
          optional
        end

        _, p = d.from_input 5
        assert_equal 5, p.unwrap

        p.freeze
        u = p.update_in(6, [])
        assert u.is_undefined?
      end

      def test_set_value_with_invalid_value_and_undefine_constraint_sets_default_having_parameter_to_default
        d = Builder.define_integer(:param) do
          constrain :range, (1..5), strategy: :undefine
          default 3
        end

        _, p = d.from_input 5
        assert_equal 5, p.unwrap

        p.set_value 6
        assert_equal 3, p.unwrap
      end

      def test_set_value_with_invalid_value_and_undefine_constraint_sets_optional_parameter_to_undefined
        d = Builder.define_integer(:param) do
          constrain :range, (1..5), strategy: :undefine
          optional
        end

        _, p = d.from_input 5
        assert_equal 5, p.unwrap

        p.set_value 6
        assert p.is_undefined?
      end

      def test_chained_constraints_raise_if_first_ignores
        d = Builder.define_integer(:param) do
          constrain :range, (1..5), strategy: :undefine
          constrain :range, (2..4)
        end

        _, p = d.from_input 4
        assert_equal 4, p.unwrap

        r, p = d.from_input 6
        refute r.ok?

        err = assert_raises(ValueMissingError) do
          p.unwrap
        end

        assert_equal 'param: value is nil', err.message
      end
    end

    class UpdateInValueParameterTest < Minitest::Test
      def test_update_in_returns_duplicate_if_parameter_unfrozen
        p = Builder.define_integer(:param).create
        p.set_value 5
        updated = p.update_in(5, [])
        assert_operator updated.object_id, :!=, p.object_id
      end

      def test_update_in_fails_if_path_is_not_terminated
        p = Builder.define_integer(:param).create.freeze
        err = assert_raises do
          p.update_in(5, [:other])
        end
        assert_equal "Expected path to be terminated in 'param'", err.message
      end

      def test_update_not_performed_if_new_value_equal_to_old
        p = Builder.define_integer(:param).create
        p.set_value 5
        p.freeze
        result, updated = p.update_if_applicable(5, [])
        assert_equal false, result
        assert_equal updated.object_id, p.object_id
      end

      def test_update_performed_if_new_value_different_from_old
        p = Builder.define_integer(:param).create
        p.set_value 5
        p.freeze
        result, updated = p.update_if_applicable(10, [])
        assert_equal true, result
        assert_operator updated.object_id, :!=, p.object_id
      end

      def test_update_in_works_with_raising_constraint
        d = Builder.define_hash(:param) do
          add :integer, :number do
            constrain :operator, :<=, 10, strategy: :raise
          end
          add :string, :text
        end
        _, p = d.from_input({ number: 5, text: 'FOO' })
        p.freeze
        err = assert_raises(Value::Constraint::Error) do
          result, updated = p.update_if_applicable(11, [:number])
        end
        assert_equal "value '11' not <= 10", err.message
      end

      def test_update_in_works_with_undefining_constraint
        d = Builder.define_hash(:param) do
          add :integer, :number do
            constrain :operator, :<=, 10, strategy: :undefine
            default 3
          end
          add :string, :text
        end
        _, p = d.from_input({ number: 5, text: 'FOO' })
        p.freeze
        result, updated = p.update_if_applicable(11, [:number])
        assert_equal true, result
        assert_equal 3, updated[:number].unwrap
      end

      def test_update_in_works_with_clamping_constraint
        d = Builder.define_hash(:param) do
          add :integer, :number do
            constrain :operator, :<=, 10, strategy: :clamp
          end
          add :string, :text
        end
        _, p = d.from_input({ number: 5, text: 'FOO' })
        p.freeze
        result, updated = p.update_if_applicable(11, [:number])
        assert_equal true, result
        assert_equal 10, updated[:number].unwrap
      end
    end

    class ValueCoderUsingContextTest < Minitest::Test
      def test_coder_uses_context_on_coercion
        d = ContextUsingParameter.get_def
        ctx = InputContext.new(:frontend, { inc: 1 })
        _, p = d.from_input({ using_context: 5 }, context: ctx)
        assert_equal 6, p[:using_context].unwrap
      end

      def test_coder_uses_context_with_frontend_formatting
        d = ContextUsingParameter.get_def
        p = d.create
        p[:using_context] = 6
        _, data = Builder.define_hash :data do
          add :integer, :dec
        end.from_input({ dec: 1 })
        data = data.freeze
        out = p.to_hash(:frontend, restriction: Restriction.blanket_permission, data: data)
        assert_equal({ param: { using_context: '5' }}, out)
        out = p.for_output(:frontend, restriction: Restriction.blanket_permission, data: data)
        assert_equal({ using_context: '5' }, out)
        out = p.for_frontend(restriction: Restriction.blanket_permission, data: data)
        assert_equal({ using_context: '5' }, out)
        out = p.for_model(restriction: Restriction.blanket_permission)
        assert_equal({ using_context: 6 }, out)
      end
    end
  end
end