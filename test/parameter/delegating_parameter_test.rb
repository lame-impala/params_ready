require_relative '../test_helper'
require_relative '../../lib/params_ready/query/structured_grouping'

module ParamsReady
  module Parameter
    class DelegatingParameterTest < Minitest::Test
      def get_delegating_param_definition
        Query::FixedOperatorPredicateBuilder.instance(:test).include do
          operator :equal
          type(:value, :integer) { optional }
        end.build
      end

      def get_delegating_param
        get_delegating_param_definition.create
      end

      def test_local_delegate_is_populated
        d = Query::FixedOperatorPredicateBuilder.instance(:test).include do
          operator :equal
          type(:value, :integer) { optional }
          local
          optional
          populate do |context, param|
            param.set_value(context[:loc])
          end
        end.build

        context = InputContext.new(:frontend, { loc: 178 })
        _, p = d.from_hash({}, context: context)
        assert_equal 178, p.unwrap
      end

      def test_inferred_default_works
        p = Query::StructuredGroupingBuilder.instance(:inferred).include do
          exists_predicate :inferred do
            arel_table Subscription.arel_table
            fixed_operator_predicate :category do
              operator :equal
              type(:value, :integer) { optional }
            end
            default :inferred
          end
          default :inferred
        end.build.create
        assert p.default_defined?
      end

      def test_set_value_works_with_delegee
        p = get_delegating_param

        data = p.instance_variable_get(:@data).dup
        data.set_value 5

        p.set_value data
        assert_equal 5, p.unwrap
      end

      def test_set_value_works_with_delegator
        p = get_delegating_param

        clone = p.dup
        clone.set_value 5

        p.set_value clone
        assert_equal 5, p.unwrap
      end

      def test_set_from_hash_works_with_delegee
        p = get_delegating_param

        data = p.instance_variable_get(:@data).dup
        data.set_value 5

        p.set_from_hash({ test: data }, context: Format.instance(:frontend))
        assert_equal 5, p.unwrap
      end

      def test_set_from_hash_works_with_delegator
        p = get_delegating_param

        clone = p.dup
        clone.set_value 5

        p.set_from_hash({ test: clone }, context: Format.instance(:frontend))
        assert_equal 5, p.unwrap
      end

      def test_from_hash_works_with_delegator_definition
        d = get_delegating_param_definition

        instance = d.create
        instance.set_value 5

        _, p = d.from_hash({ test: instance })
        assert_equal 5, p.unwrap
      end

      def test_dup_works_with_delegator
        p = get_delegating_param
        p.set_value 10
        clone = p.dup
        clone.set_value 5
        assert_equal 10, p.unwrap
      end

      def test_delegators_equal_when_coming_from_same_definition_and_have_same_value
        d = get_delegating_param_definition
        _, a = d.from_input(5)
        _, b = d.from_input(5)
        assert_params_equal(a, b)
      end

      def test_delegators_not_equal_when_coming_from_same_definition_and_have_different_value
        d = get_delegating_param_definition
        _, a = d.from_input(5)
        _, b = d.from_input(6)
        refute_params_equal(a, b)
      end

      def test_delegators_not_equal_when_coming_from_different_definition_and_have_same_value
        da = get_delegating_param_definition
        db = get_delegating_param_definition
        _, a = da.from_input(5)
        _, b = db.from_input(5)
        refute_params_equal(a, b)
      end
    end

    class UpdateInForDelegatingParameterTest < Minitest::Test
      def get_def
        Query::StructuredGroupingBuilder.instance(:grouping).include do
          custom_predicate :hash_based do
            type :hash do
              add :integer, :detail do
                default 0
              end
              add :string, :search do
                default ''
              end
            end
            default :inferred
          end
          default :inferred
        end.build
      end

      def initial_value
        { grouping: { hash_based: { detail: 5, search: 'stuff' }}}
      end

      def test_update_if_applicable_called_on_self_works_with_unfrozen_param
        d = get_def
        _, p = d.from_hash(initial_value, context: :backend)
        changed, u = p.update_if_applicable({ detail: 4, search: 'other'}, [:hash_based])
        assert changed
        refute u.frozen?
        refute u[:hash_based].frozen?
        refute u[:hash_based][:search].frozen?

        assert_equal 4, u[:hash_based][:detail].unwrap
        assert_equal 'other', u[:hash_based][:search].unwrap
        assert_different p, u
        assert_different p[:hash_based], u[:hash_based]
        assert_different p[:hash_based][:search], u[:hash_based][:search]
      end

      def test_update_if_applicable_called_on_self_works_with_frozen_param
        d = get_def
        _, p = d.from_hash(initial_value, context: :backend)
        p.freeze
        changed, u = p.update_if_applicable({ detail: 4, search: 'other'}, [:hash_based])
        assert changed
        assert u.frozen?
        assert u[:hash_based].frozen?
        assert u[:hash_based][:search].frozen?

        assert_equal 4, u[:hash_based][:detail].unwrap
        assert_equal 'other', u[:hash_based][:search].unwrap
        assert_different p, u
        assert_different p[:hash_based], u[:hash_based]
        assert_different p[:hash_based][:search], u[:hash_based][:search]
      end

      def test_update_if_applicable_called_on_child_with_different_value_works_with_unfrozen_param
        d = get_def
        _, p = d.from_hash(initial_value, context: :backend)

        changed, u = p.update_if_applicable('other', [:hash_based, :search])
        assert changed
        refute u.frozen?
        refute u[:hash_based].frozen?
        refute u[:hash_based][:detail].frozen?
        refute u[:hash_based][:search].frozen?

        assert_equal 5, u[:hash_based][:detail].unwrap
        assert_equal 'other', u[:hash_based][:search].unwrap
        assert_different p, u
        assert_different p[:hash_based], u[:hash_based]
        assert_different p[:hash_based][:detail], u[:hash_based][:detail]
        assert_different p[:hash_based][:search], u[:hash_based][:search]
      end

      def test_update_if_applicable_called_on_child_with_different_value_works_with_frozen_param
        d = get_def
        _, p = d.from_hash(initial_value, context: :backend)
        p.freeze

        changed, u = p.update_if_applicable('other', [:hash_based, :search])
        assert changed

        assert u.frozen?
        assert u[:hash_based].frozen?
        assert u[:hash_based][:detail].frozen?
        assert u[:hash_based][:search].frozen?

        assert_equal 5, u[:hash_based][:detail].unwrap
        assert_equal 'other', u[:hash_based][:search].unwrap
        assert_different p, u
        assert_different p[:hash_based], u[:hash_based]
        assert_same p[:hash_based][:detail], u[:hash_based][:detail]
        assert_different p[:hash_based][:search], u[:hash_based][:search]
      end

      def test_update_if_applicable_called_on_child_with_equal_value_works_with_frozen_param
        d = get_def
        _, p = d.from_hash(initial_value, context: :backend)
        p.freeze

        changed, u = p.update_if_applicable('stuff', [:hash_based, :search])
        refute changed

        assert_same p, u
      end
    end
  end
end