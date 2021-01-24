require_relative '../test_helper'
require_relative '../../lib/params_ready/parameter/tuple_parameter'
require_relative '../../lib/params_ready/value/validator'
require_relative '../../lib/params_ready/value/coder'

module ParamsReady
  module Parameter
    class TupleParameterTest < Minitest::Test
      def get_def(fields:, default: Extensions::Undefined, optional: false, marshal: { using: :string, separator: "|" })
        Builder.define_tuple(:tuple, altn: :tpl) do
          fields.each do |field|
            self.field field
          end
          self.optional if optional
          default(default) unless default == Extensions::Undefined
          marshal(**marshal)
        end
      end

      def get_param(*args, **opts)
        get_def(*args, **opts).create
      end

      def get_fields
        range = Value::Validator.instance(Value::RangeConstraint.new(0..5))
        enum = Value::Validator.instance(Value::EnumConstraint.new(%w(one two three)))
        first = ValueParameterDefinition.new(:number, Value::IntegerCoder, altn: :nm, constraints: [range]).finish
        second = ValueParameterDefinition.new(:string, Value::StringCoder, altn: :str, constraints: [enum]).finish
        [first, second]
      end

      def test_ordinal_method_names_work
        first = ValueParameterDefinition.new(:number, Value::IntegerCoder, altn: :nm).finish
        second = ValueParameterDefinition.new(:string, Value::StringCoder, altn: :str).finish
        third = ValueParameterDefinition.new(:boolean, Value::BooleanCoder, altn: :bool).finish
        p = get_param(fields: [first, second, third])
        p.set_value [5, 'foo', true]
        assert p.send :respond_to_missing?, :first
        assert p.send :respond_to_missing?, :second
        assert p.send :respond_to_missing?, :third
        refute p.send :respond_to_missing?, :fourth
        assert_equal 5, p.first.unwrap
        assert_equal 'foo', p.second.unwrap
        assert_equal true, p.third.unwrap
      end

      def test_field_can_not_be_added_after_default_has_been_set
        err = assert_raises do
          Builder.define_tuple(:faulty) do
            field :integer, :first
            default [0]
            field :string, :second
          end
        end

        assert_equal "Can't add field if default is present", err.message
      end

      def test_to_hash_if_eligible_omits_default_values_if_always_flag_is_false
        first, second = get_fields
        p = get_param(fields: [first, second], default: [0, 'one'])
        assert_nil(p.to_hash_if_eligible(Intent.instance(:minify_only)))
      end

      def test_if_one_value_is_reset_values_are_written_regardless_of_flag
        first, second = get_fields
        p = get_param(fields: [first, second], default: [0, 'one'])
        p[0] = 1
        assert_equal({ tpl: '1|one' }, p.to_hash_if_eligible(Intent.instance(:frontend)))
        p = get_param(fields: [first, second], default: [0, 'one'])
        p[1] = 'two'
        assert_equal({ tpl: '0|two' }, p.to_hash_if_eligible(Intent.instance(:frontend)))
      end

      def test_to_hash_if_eligible_writes_default_values_if_minify_is_false
        first, second = get_fields
        p = get_param(fields: [first, second], default: [0, 'one'])
        hash = p.to_hash_if_eligible(Intent.instance(:marshal_alternative))
        assert_equal({ tpl: '0|one' }, hash)
      end

      def test_from_hash_uses_default_if_hash_is_nil
        first, second = get_fields
        d = get_def(fields: [first, second], default: [0, 'one'])
        _, p = d.from_hash({})
        assert_equal(0, p[0].unwrap)
        assert_equal('one', p[1].unwrap)
      end

      def test_from_hash_sets_correct_values_if_hash_present
        first, second = get_fields
        d = get_def(fields: [first, second], default: [0, 'one'])
        _, p = d.from_hash({ tpl: '2|three' })
        assert_equal(2, p[0].unwrap)
        assert_equal('three', p[1].unwrap)
      end

      def test_coerces_from_hash_with_numerical_indexes
        first, second = get_fields
        d = get_def(fields: [first, second], default: [0, 'one'])
        _, p = d.from_hash({ tpl: { '0' => '2', '1' => 'three' }})
        assert_equal(2, p[0].unwrap)
        assert_equal('three', p[1].unwrap)
      end

      def test_can_be_set_to_marshal_to_hash
        first, second = get_fields
        d = get_def(fields: [first, second], default: [0, 'one'], marshal: { to: Hash })
        hash = { tpl: { '0' => '2', '1' => 'three' }}
        _, p = d.from_hash(hash)
        assert_equal(hash, p.to_hash(:frontend))
      end
    end

    class TupleParameterUpdateInTest < Minitest::Test
      def get_def
        Builder.define_tuple :updating do
          field :integer, :detail
          field :symbol, :type do
            constrain :enum, [:a, :b, :c]
          end
          marshal using: :string, separator: '|'
        end
      end

      def initial_value
        { updating: [1, :a] }
      end

      def test_update_if_applicable_works_if_called_on_unfrozen_self
        d = get_def
        _, p = d.from_hash(initial_value)

        changed, u = p.update_if_applicable([2, :b], [])
        assert changed
        assert_equal(2, u[0].unwrap)
        assert_equal(:b, u[1].unwrap)
        assert_different u, p
        refute u.frozen?
        refute u[0].frozen?
        refute u[1].frozen?
      end

      def test_update_if_applicable_works_if_called_on_frozen_self
        d = get_def
        _, p = d.from_hash(initial_value)
        p.freeze

        changed, u = p.update_if_applicable([2, :b], [])
        assert changed
        assert_equal(2, u[0].unwrap)
        assert_equal(:b, u[1].unwrap)
        assert_different u, p
        assert_different u[0], p[0]
        assert_different u[1], p[1]

        assert u.frozen?
        assert u[0].frozen?
        assert u[1].frozen?
      end

      def test_update_if_applicable_works_if_called_on_child_of_unfrozen_parameter_with_different_value
        d = get_def
        _, p = d.from_hash(initial_value)

        changed, u = p.update_if_applicable(10, [0])
        assert changed
        assert_equal(10, u[0].unwrap)
        assert_equal(:a, u[1].unwrap)
        refute_same u, p
        refute_same u[0], p[0]
        refute_same u[1], p[1]

        refute u.frozen?
        refute u[0].frozen?
        refute u[1].frozen?
      end

      def test_update_if_applicable_works_if_called_on_child_of_frozen_parameter_with_different_value
        d = get_def
        _, p = d.from_hash(initial_value)
        p.freeze

        changed, u = p.update_if_applicable(10, [0])
        assert changed
        assert_equal(10, u[0].unwrap)
        assert_equal(:a, u[1].unwrap)
        refute_same u, p
        refute_same u[0], p[0]
        assert_same u[1], p[1]
        assert u.frozen?
        assert u[0].frozen?
        assert u[1].frozen?
      end

      def test_update_if_applicable_works_if_called_on_child_of_frozen_parameter_with_same_value
        d = get_def
        _, p = d.from_hash(initial_value)
        p.freeze

        changed, u = p.update_if_applicable(1, [0])
        refute changed
        assert_equal(1, u[0].unwrap)
        assert_equal(:a, u[1].unwrap)
        assert_same u, p
        assert_same u[0], p[0]
        assert_same u[1], p[1]
        assert u.frozen?
        assert u[0].frozen?
        assert u[1].frozen?
      end
    end
  end
end