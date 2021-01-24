require_relative '../test_helper'
require_relative '../../lib/params_ready/query/polymorph_predicate'
require_relative '../../lib/params_ready/query/fixed_operator_predicate'
require_relative '../../lib/params_ready/query/variable_operator_predicate'

module ParamsReady
  module Query
    class PolymorphPredicateTest < Minitest::Test
      def get_predicate_definition(optional: nil, predicate_default: Extensions::Undefined)
        builder = PolymorphPredicateBuilder.instance :polymorph, altn: :pm
        builder.type :fixed_operator_predicate, :email_like, altn: :eml_lk, attr: :email do
          operator :like
          type :value, :string do
            default('Default') if predicate_default == :email_like
          end
        end
        builder.type :variable_operator_predicate, :role_variable_operator, altn: :rl_vop, attr: :role do
          operators :equal, :greater_than_or_equal, :less_than_or_equal
          type :value, :integer
          default({ operator: :equal, value: 0 }) if predicate_default == :role_variable_operator
        end
        builder.optional if optional
        builder.default(predicate_default) unless predicate_default == Extensions::Undefined
        builder.build
      end

      def get_predicate(*args)
        get_predicate_definition(*args).create
      end


      def test_predicate_can_be_optional
        d = get_predicate_definition(optional: true)
        _, predicate = d.from_hash({})
        assert_nil predicate.to_hash_if_eligible(Intent.instance(:frontend))
        assert_equal({ polymorph: nil }, predicate.to_hash_if_eligible(Intent.instance(:backend)))
        assert_nil predicate.unwrap

        assert_nil predicate.to_query_if_eligible(:whatever, context: Restriction.blanket_permission)
        assert_nil predicate.test(:whatever)
      end

      def test_predicate_can_have_default
        d = get_predicate_definition(predicate_default: :email_like)
        _, predicate = d.from_hash({})
        assert_nil predicate.to_hash_if_eligible(Intent.instance(:frontend))
        lk = PredicateRegistry.operator(:lk, Format.instance(:frontend))

        be = { polymorph: { email_like: 'Default' }}
        assert_equal be, predicate.to_hash_if_eligible(Intent.instance(:backend))
        assert_equal be[:polymorph], predicate.unwrap
        assert_equal '"users"."email" LIKE \'%Default%\'', predicate.to_query(User.arel_table).to_sql
        u = User.new(id: 2, email: 'default', role: 'client')
        assert predicate.test(u)
      end

      def test_delegating_parameter_works
        predicate = get_predicate
        predicate.set_value(
          role_variable_operator: {
            value: 10, operator: :greater_than_or_equal
          }
        )
        clone = predicate.dup
        assert_equal clone, predicate
        assert clone.is_definite?
        refute clone.is_nil?
        refute clone.is_undefined?
        refute clone.is_default?
        gteq = PredicateRegistry.operator :gteq, Format.instance(:frontend)
        assert_equal({ role_variable_operator: { operator: gteq, value: 10 }}, clone.unwrap)
        assert_equal({ rl_vop: { op: :gteq, val: '10' }}, clone.format(Intent.instance(:frontend)))
        assert_equal({ polymorph: { role_variable_operator: { operator: gteq, value: 10 }}}, clone.to_hash_if_eligible)
        clone.set_from_hash({ polymorph: {role_variable_operator: { operator: gteq, value: 5 }}}, context: Format.instance(:backend))
        assert_equal({ role_variable_operator: { operator: gteq, value: 5 }}, clone.unwrap)
      end

      def test_to_query_works
        predicate = get_predicate
        predicate.set_value(
          role_variable_operator: {
            value: 10, operator: :greater_than_or_equal
          }
        )
        assert_equal '"users"."role" >= 10', predicate.to_query(User.arel_table).to_sql
        predicate.set_value(
          role_variable_operator: {
            value: 3, operator: :equal
          }
        )
        assert_equal '"users"."role" = 3', predicate.to_query(User.arel_table).to_sql
        predicate.set_value(email_like: 'xyz')
        assert_equal '"users"."email" LIKE \'%xyz%\'', predicate.to_query(User.arel_table).to_sql
      end

      def x_test_test_works
        good = User.new(id: 2, email: 'good@example.com', role: 10)
        bad = User.new(id: 1, email: 'bad@example.com', role: 3)
        predicate = get_predicate
        predicate.set_value(
          role_variable_operator: {
            value: 10, operator: :greater_than_or_equal
          }
        )

        assert predicate.test(good)
        refute predicate.test(bad)

        predicate.set_value(email_like: 'good')
        refute predicate.test(good)
        assert predicate.test(bad)
      end
    end
  end
end