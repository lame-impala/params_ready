require_relative '../test_helper'
require_relative '../../lib/params_ready/query/fixed_operator_predicate'

module ParamsReady
  module Query
    class FixedOperatorPredicateTest < Minitest::Test
      def get_predicate(name, altn, type, operator, optional: false, default: Extensions::Undefined, table: nil)
        builder = FixedOperatorPredicateBuilder.instance name, altn: altn
        builder.instance_eval do
          operator operator
          type(:value, type)
          optional() if optional
          default(default) unless default == Extensions::Undefined
          arel_table table unless table.nil?
        end
        definition = builder.build
        definition.create
      end

      def get_array_predicate(name, altn, operator)
        builder = FixedOperatorPredicateBuilder.instance name, altn: altn
        builder.operator operator
        builder.type :array do
          prototype :integer
        end

        definition = builder.build
        definition.create
      end

      def get_hash_set_predicate
        builder = FixedOperatorPredicateBuilder.instance :stage_in, altn: :stg_in, attr: :stage
        builder.operator :in

        builder.type :hash_set do
          add(:pending) { optional }
          add(:processing) { optional }
          add(:complete) { optional }
        end

        definition = builder.build
        definition.create
      end

      def test_predicate_can_be_optional
        predicate = get_predicate :email, :eml, :string, :equal, optional: true
        assert_nil predicate.unwrap
        assert_nil predicate.to_hash_if_eligible(Intent.instance(:frontend))
        assert_equal({ email: nil }, predicate.to_hash_if_eligible(Intent.instance(:backend)))
        assert_nil predicate.to_query_if_eligible(:whatever, context: Restriction.blanket_permission)
        assert_nil predicate.test(:whatever)
      end

      def test_predicate_can_have_default
        predicate = get_predicate :email, :eml, :string, :like, default: 'some'
        assert_nil predicate.to_hash_if_eligible(Intent.instance(:frontend))
        assert_equal({ email: 'some' }, predicate.to_hash_if_eligible(Intent.instance(:backend)))
        assert_equal 'some', predicate.unwrap
        assert_equal '"users"."email" LIKE \'%some%\'', predicate.to_query(User.arel_table).to_sql
        u = User.new(id: 1, email: 'some@example.com', role: 'user')
        assert predicate.test(u)
      end

      def test_delegating_parameter_works
        predicate = get_predicate :email, :eml, :string, :equal
        predicate.set_value 'bogus'
        clone = predicate.dup
        assert_equal clone, predicate
        assert clone.is_definite?
        refute clone.is_nil?
        refute clone.is_undefined?
        refute clone.is_default?
        assert_equal('bogus', clone.unwrap)
        assert_equal('bogus', clone.format(Intent.instance(:backend)))
        assert_equal({ email: 'bogus' }, clone.to_hash_if_eligible)
        clone.set_from_hash({ eml: 'other' }, context: Format.instance(:frontend))
        assert_equal('other', clone.unwrap)
      end

      def test_equal_operator_works
        predicate = get_predicate :email, :eml, :string, :equal
        predicate.set_value 'bogus'

        query = predicate.to_query(User.arel_table)
        assert_equal "users.email = 'bogus'", query.to_sql.unquote

        u1 = User.new id: 1, email: 'bogus', role: 5
        u2 = User.new id: 2, email: 'other', role: 5

        assert predicate.test(u1)
        refute predicate.test(u2)
      end

      def test_predicate_works_with_arel_table_none
        predicate = get_predicate :ranking, :rnk, :string, :equal, table: :none
        predicate.set_value 'bogus'

        query = predicate.to_query(User.arel_table)
        assert_equal "ranking = 'bogus'", query.to_sql.unquote
      end

      def test_not_equal_operator_works
        predicate = get_predicate :email, :eml, :string, :not_equal
        predicate.set_value 'bogus'

        query = predicate.to_query(User.arel_table)
        assert_equal "users.email != 'bogus'", query.to_sql.unquote

        u1 = User.new id: 1, email: 'bogus', role: 5
        u2 = User.new id: 2, email: 'other', role: 5

        refute predicate.test(u1)
        assert predicate.test(u2)
      end

      def test_like_operator_works
        predicate = get_predicate :email, :eml, :string, :like
        predicate.set_value 'bogus'

        query = predicate.to_query(User.arel_table)
        assert_equal "users.email LIKE '%bogus%'", query.to_sql.unquote

        u1 = User.new id: 1, email: 'xbogusx', role: 5
        u2 = User.new id: 2, email: 'other', role: 5

        assert predicate.test(u1)
        refute predicate.test(u2)
      end

      def test_not_like_operator_works
        predicate = get_predicate :email, :eml, :string, :not_like
        predicate.set_value 'bogus'

        query = predicate.to_query(User.arel_table)
        assert_equal "NOT (users.email LIKE '%bogus%')", query.to_sql.unquote

        u1 = User.new id: 1, email: 'xbogusx', role: 5
        u2 = User.new id: 2, email: 'other', role: 5

        refute predicate.test(u1)
        assert predicate.test(u2)
      end

      def test_greater_than_operator_works
        predicate = get_predicate :role, :rl, :integer, :greater_than
        predicate.set_value 5

        query = predicate.to_query(User.arel_table)
        assert_equal "users.role > 5", query.to_sql.unquote

        u1 = User.new id: 1, email: 'xbogusx', role: 6
        u2 = User.new id: 2, email: 'other', role: 5

        assert predicate.test(u1)
        refute predicate.test(u2)
      end

      def test_less_than_operator_works
        predicate = get_predicate :role, :rl, :integer, :less_than
        predicate.set_value 5

        query = predicate.to_query(User.arel_table)
        assert_equal "users.role < 5", query.to_sql.unquote

        u1 = User.new id: 1, email: 'xbogusx', role: 4
        u2 = User.new id: 2, email: 'other', role: 5

        assert predicate.test(u1)
        refute predicate.test(u2)
      end

      def test_greater_than_or_equal_operator_works
        predicate = get_predicate :role, :rl, :integer, :greater_than_or_equal
        predicate.set_value 5

        query = predicate.to_query(User.arel_table)
        assert_equal "users.role >= 5", query.to_sql.unquote

        u1 = User.new id: 1, email: 'xbogusx', role: 5
        u2 = User.new id: 2, email: 'other', role: 4

        assert predicate.test(u1)
        refute predicate.test(u2)
      end

      def test_less_than_or_equal_operator_works
        predicate = get_predicate :role, :rl, :integer, :less_than_or_equal
        predicate.set_value 5

        query = predicate.to_query(User.arel_table)
        assert_equal "users.role <= 5", query.to_sql.unquote

        u1 = User.new id: 1, email: 'xbogusx', role: 5
        u2 = User.new id: 2, email: 'other', role: 6

        assert predicate.test(u1)
        refute predicate.test(u2)
      end

      def test_in_operator_works
        predicate = get_array_predicate :role, :rl, :in

        predicate.set_value [5, 6]

        query = predicate.to_query(User.arel_table)
        assert_equal "users.role IN (5, 6)", query.to_sql.unquote

        u1 = User.new id: 1, email: 'xbogusx', role: 5
        u2 = User.new id: 2, email: 'other', role: 6
        u3 = User.new id: 3, email: 'xbogusx', role: 7

        assert predicate.test(u1)
        assert predicate.test(u2)
        refute predicate.test(u3)
      end

      def test_in_operator_works_with_custom_marshaller
        builder = FixedOperatorPredicateBuilder.instance :stringy, attr: :role
        builder.operator :in
        builder.type :array do
          prototype :string do
            optional
          end
          marshal using: :string, separator: '; ', split_pattern: /\s*[;,]\s*/
          compact
        end

        definition = builder.build
        _, predicate = definition.from_input('a; b, c, ')

        query = predicate.to_query(User.arel_table)
        assert_equal "users.role IN ('a', 'b', 'c')", query.to_sql.unquote
        assert_equal 'a; b; c', predicate.format(Format.instance(:frontend))
      end

      def test_not_in_operator_works
        predicate = get_array_predicate :role, :rl, :not_in

        predicate.set_value [5, 6]

        query = predicate.to_query(User.arel_table)
        assert_equal "NOT (users.role IN (5, 6))", query.to_sql.unquote

        u1 = User.new id: 1, email: 'xbogusx', role: 5
        u2 = User.new id: 2, email: 'other', role: 6
        u3 = User.new id: 3, email: 'xbogusx', role: 7

        refute predicate.test(u1)
        refute predicate.test(u2)
        assert predicate.test(u3)
      end

      def test_in_operator_works_with_hash_set
        predicate = get_hash_set_predicate

        predicate.set_value [:pending, :processing]

        query = predicate.to_query(User.arel_table)
        assert_equal "users.stage IN ('pending', 'processing')", query.to_sql.unquote
      end

      def test_operators_inverted_correctly
        op = PredicateRegistry.operator(:greater_than, Format.instance(:backend))
        nop = PredicateRegistry.operator(:not_less_than_or_equal, Format.instance(:backend))
        assert_equal op, nop

        op = PredicateRegistry.operator(:less_than, Format.instance(:backend))
        nop = PredicateRegistry.operator(:not_greater_than_or_equal, Format.instance(:backend))
        assert_equal op, nop

        op = PredicateRegistry.operator(:greater_than_or_equal, Format.instance(:backend))
        nop = PredicateRegistry.operator(:not_less_than, Format.instance(:backend))
        assert_equal op, nop

        op = PredicateRegistry.operator(:less_than_or_equal, Format.instance(:backend))
        nop = PredicateRegistry.operator(:not_greater_than, Format.instance(:backend))
        assert_equal op, nop
      end
    end
  end
end