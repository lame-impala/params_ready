require_relative '../test_helper'
require_relative '../../lib/params_ready/query/structured_grouping.rb'
require_relative '../../lib/params_ready/value/validator'

module ParamsReady
  class StructuredGroupingTest < Minitest::Test
    module Query
      def get_definition(op: :and, optional: false, predicate_default: Extensions::Undefined)
        builder = StructuredGroupingBuilder.instance(:grouping, altn: :grp)
        builder.instance_eval do
          fixed_operator_predicate :email_like, altn: :eml_lk, attr: :email do
            operator :like
            type :value, :string do
              optional()
            end
          end
          fixed_operator_predicate :role_less_than_or_equal, altn: :rl_lteq, attr: :role do
            operator :less_than_or_equal
            type :value, :integer do
              constrain :range, 1..10
              optional()
            end
          end
          operator do
            default op
          end
          optional() if optional
          default(predicate_default) unless predicate_default == Extensions::Undefined
        end
        builder.build
      end

      def get_predicate(**opts)
        get_definition(**opts).create
      end

      def test_predicate_can_be_optional
        d = get_definition(optional: true)
        _, predicate = d.from_hash({})
        assert_nil predicate.to_hash_if_eligible(Intent.instance(:frontend))
        assert_equal({ grouping: nil }, predicate.to_hash_if_eligible(Intent.instance(:backend)))
        assert_nil predicate.unwrap
        assert_nil predicate.to_query(:whatever)
        assert predicate.test(:whatever)
      end

      def test_delegating_parameter_works
        predicate = get_predicate

        predicate.set_value(value1)
        clone = predicate.dup
        assert_equal clone, predicate
        assert clone.is_definite?
        refute clone.is_nil?
        refute clone.is_undefined?
        refute clone.is_default?

        exp = value1
        exp[:operator] = GroupingOperator.instance(:and)
        assert_equal(exp, clone.unwrap)
        assert_equal({ eml_lk: 'bogus', rl_lteq: '10' }, clone.format(Intent.instance(:frontend)))

        clone.set_value(value2)
        exp = value2
        exp[:operator] = GroupingOperator.instance(:or)
        assert_equal(exp, clone.unwrap)
      end

      def test_to_query_works
        predicate = get_predicate
        predicate.set_value(value1)
        assert_equal "(users.email LIKE '%bogus%' AND users.role <= 10)", predicate.to_query(User.arel_table).to_sql.unquote
        predicate.set_value(value2)
        assert_equal "(users.email LIKE '%bogus%' OR users.role <= 10)", predicate.to_query(User.arel_table).to_sql.unquote
        predicate.set_value(value3)
        assert_equal '(users.role <= 10)', predicate.to_query(User.arel_table).to_sql.unquote
      end

      def test_test_works
        good = User.new(id: 2, email: 'bogus@example.com', role: 10)
        soso = User.new(id: 1, email: 'bad@example.com', role: 10)
        bad = User.new(id: 1, email: 'bad@example.com', role: 19)
        predicate = get_predicate

        predicate.set_value(value1)
        assert predicate.test(good)
        refute predicate.test(soso)
        refute predicate.test(bad)

        predicate.set_value(value2)
        assert predicate.test(good)
        assert predicate.test(soso)
        refute predicate.test(bad)
      end

      def test_restriction_works
        d = get_definition
        p = Builder.define_parameter :hash, :parameter, altn: :p do
          add d
        end.create
        p.set_value(grouping: value1)
        al = Restriction.permit(:email_like)
        dl = Restriction.prohibit(:role_less_than_or_equal)

        with_query_context restrictions: [al, dl] do |context|
          q = p[:grouping].to_query(User.arel_table, context: context).to_sql.unquote
          assert_equal "(users.email LIKE '%bogus%')", q
        end

        int = Intent.instance(:backend).permit(grouping: [:email_like])
        dec = OutputParameters.decorate(p.freeze, int)
        assert_equal({ parameter: { grouping: { email_like: "bogus" }}}, dec.to_hash(int))

        with_query_context restrictions: [al, dl] do |context|
          assert_equal "(users.email LIKE '%bogus%')", p[:grouping].to_query(User.arel_table, context: context).to_sql.unquote
        end
      end

      def value1
        {
          email_like: 'bogus',
          role_less_than_or_equal: 10,
          operator: :and
        }
      end

      def value2
        {
          email_like: 'bogus',
          role_less_than_or_equal: 10,
          operator: :or
        }
      end

      def value3
        {
          role_less_than_or_equal: 10,
          operator: :and
        }
      end
    end
  end
end