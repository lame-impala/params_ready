require_relative '../test_helper'
require_relative '../../lib/params_ready/query/relation.rb'

module ParamsReady
  module Query
    module GroupingTestHelper
      def get_def(op: :and, relation_optional: false, relation_default: Extensions::Undefined)
        Builder.define_relation(:user, altn: :usr) do
          model User
          fixed_operator_predicate :email_like, altn: :eml_lk, attr: :email do
            operator :like
            type :value, :string do
              optional
            end
          end
          fixed_operator_predicate :role_less_than_or_equal, altn: :rl_lteq, attr: :role do
            operator :less_than_or_equal
            type :value, :integer do
              optional
              constrain :range, 1..10
            end
          end
          operator do
            local op
          end
          paginate(100, 500)
          order do
            column :email, :asc
            column :role, :desc
            column :standing, :asc, arel_table: :none
            default [:email, :asc]
          end
          optional() if relation_optional
          default(relation_default) unless relation_default == Extensions::Undefined
        end
      end

      def get_relation(*args, **opts)
        relation = get_def(*args, **opts)
        relation = relation.create
        relation
      end
    end

    class AndGroupingTest < Minitest::Test
      include GroupingTestHelper

      def test_restriction_works
        relation = get_relation

        relation[:email_like] = 'bogus'
        relation[:role_less_than_or_equal] = 5
        relation[:ordering] = [[:email, :asc], [:role, :desc]]

        al = Restriction.permit(:email_like, ordering: [:email])
        dl = Restriction.prohibit(:role_less_than_or_equal, ordering: [:role])

        with_query_context restrictions: [al, dl] do |context|
          query = relation.predicate_group(User.arel_table, context: context)
          assert_equal "(users.email LIKE '%bogus%')", query.to_sql.unquote
          full_query = relation.build_select(context: context)
          exp = "SELECT * FROM users WHERE (users.email LIKE '%bogus%') ORDER BY users.email ASC LIMIT 100 OFFSET 0"
          assert_equal exp, full_query.to_sql.unquote
        end
      end

      def test_pagination_can_be_ignored
        relation = get_relation
        restriction = Restriction.permit(:email_like, ordering: [:email])

        relation[:email_like] = 'bogus'
        relation[:role_less_than_or_equal] = 5
        relation[:ordering] = [[:email, :asc], [:role, :desc]]

        query = relation.predicate_group(User.arel_table, context: restriction)
        assert_equal "(users.email LIKE '%bogus%')", query.to_sql.unquote
        full_query = relation.build_select(context: restriction, paginate: false)
        exp = "SELECT * FROM users WHERE (users.email LIKE '%bogus%') ORDER BY users.email ASC"
        assert_equal exp, full_query.to_sql.unquote
      end

      def test_relation_can_be_optional
        relation = get_relation relation_optional: true
        assert_nil relation.unwrap
        assert_nil relation.to_hash_if_eligible(Intent.instance(:frontend))
        assert_equal({ user: nil }, relation.to_hash_if_eligible(Intent.instance(:backend)))
        assert_equal 'SELECT * FROM users', relation.build_select().to_sql.unquote
        assert_nil relation.test(:whatever)
      end

      def test_predicate_can_have_default
        relation = get_relation relation_default: { email_like: 'default', role_less_than_or_equal: 3 }
        assert_nil relation.to_hash_if_eligible(Intent.instance(:frontend))
        op = GroupingOperator.instance(:and)
        exp = {
          user: {
            email_like: 'default',
            role_less_than_or_equal: 3,
            operator: op,
            pagination: [0, 100],
            ordering: [[:email, :asc]]
          }
        }

        assert_equal(exp, relation.to_hash_if_eligible(Intent.instance(:backend)))
        exp = {
          email_like: 'default',
          role_less_than_or_equal: 3,
          operator: op,
          pagination: [0, 100],
          ordering: [[:email, :asc]]
        }
        assert_equal(exp, relation.unwrap)

        exp = <<~SQL
          SELECT * FROM users WHERE
          (users.email LIKE '%default%' AND users.role <= 3)
          ORDER BY users.email ASC LIMIT 100 OFFSET 0
        SQL
        query = relation.build_select
        assert_equal exp.unformat, query.to_sql.unquote
      end

      def test_qrouping_works_when_all_predicates_set
        relation = get_relation
        relation[:email_like] = 'bogus'
        relation[:role_less_than_or_equal] = 5
        query = relation.predicate_group User.arel_table
        assert_equal "(users.email LIKE '%bogus%' AND users.role <= 5)", query.to_sql.unquote
        u1 = User.new(id: 1, email: 'xbogus', role: 5)
        u2 = User.new(id: 2, email: 'other', role: 4)
        u3 = User.new(id: 3, email: 'bogus', role: 6)
        assert relation.test(u1)
        refute relation.test(u2)
        refute relation.test(u3)
        full_query = relation.build_select
        exp = <<~SQL
          SELECT * FROM users
          WHERE (users.email LIKE '%bogus%' AND users.role <= 5)
          ORDER BY users.email ASC LIMIT 100 OFFSET 0
        SQL
        assert_equal exp.unformat, full_query.to_sql.unquote
      end

      def test_qrouping_works_when_some_predicates_set
        relation = get_relation
        relation[:role_less_than_or_equal] = 5
        query = relation.predicate_group User.arel_table
        assert_equal "(users.role <= 5)", query.to_sql.unquote
        u1 = User.new(id: 1, email: 'xbogus', role: 5)
        u2 = User.new(id: 2, email: 'other', role: 4)
        u3 = User.new(id: 3, email: 'bogus', role: 6)
        assert relation.test(u1)
        assert relation.test(u2)
        refute relation.test(u3)
        full_query = relation.build_select
        exp = "SELECT * FROM users WHERE (users.role <= 5) ORDER BY users.email ASC LIMIT 100 OFFSET 0"
        assert_equal exp, full_query.to_sql.unquote
      end

      def test_count_works_when_some_predicates_set
        relation = get_relation
        relation[:role_less_than_or_equal] = 5
        full_query = relation.to_count
        exp = "SELECT COUNT(users.id) FROM users WHERE (users.role <= 5)"
        assert_equal exp, full_query.to_sql.unquote
      end

      def test_qrouping_works_when_no_predicate_set
        d = get_def
        _, relation = d.from_hash({})
        query = relation.predicate_group User.arel_table
        assert_nil query
        u1 = User.new(id: 1, email: 'xbogus', role: 5)
        assert_nil relation.test(u1)
        full_query = relation.build_select
        exp = "SELECT * FROM users ORDER BY users.email ASC LIMIT 100 OFFSET 0"
        assert_equal exp, full_query.to_sql.unquote
      end
    end

    class OrGroupingTest < Minitest::Test
      include GroupingTestHelper
      def test_qrouping_works_when_all_predicates_set
        relation = get_relation op: :or
        relation[:email_like] = 'bogus'
        relation[:role_less_than_or_equal] = 5
        query = relation.predicate_group User.arel_table
        assert_equal "(users.email LIKE '%bogus%' OR users.role <= 5)", query.to_sql.unquote
        u1 = User.new(id: 1, email: 'xbogus', role: 5)
        u2 = User.new(id: 2, email: 'other', role: 4)
        u3 = User.new(id: 3, email: 'bogus', role: 6)
        assert relation.test(u1)
        assert relation.test(u2)
        assert relation.test(u3)
        full_query = relation.build_select
        exp = <<~SQL
          SELECT * FROM users
          WHERE (users.email LIKE '%bogus%' OR users.role <= 5)
          ORDER BY users.email ASC LIMIT 100 OFFSET 0
        SQL
        assert_equal exp.unformat, full_query.to_sql.unquote
      end

      def test_qrouping_works_when_some_predicates_set
        relation = get_relation op: :or
        relation[:role_less_than_or_equal] = 5
        query = relation.predicate_group User.arel_table
        assert_equal "(users.role <= 5)", query.to_sql.unquote
        u1 = User.new(id: 1, email: 'xbogus', role: 5)
        u2 = User.new(id: 2, email: 'other', role: 4)
        u3 = User.new(id: 3, email: 'bogus', role: 6)
        assert relation.test(u1)
        assert relation.test(u2)
        refute relation.test(u3)
        full_query = relation.build_select
        exp = "SELECT * FROM users WHERE (users.role <= 5) ORDER BY users.email ASC LIMIT 100 OFFSET 0"
        assert_equal exp, full_query.to_sql.unquote
      end

      def test_count_works_when_some_predicates_set
        relation = get_relation op: :or
        relation[:role_less_than_or_equal] = 5
        full_query = relation.to_count
        exp = "SELECT COUNT(users.id) FROM users WHERE (users.role <= 5)"
        assert_equal exp, full_query.to_sql.unquote
      end

      def test_qrouping_works_when_no_predicates_set
        d = get_def op: :or
        _, relation = d.from_hash({})
        query = relation.predicate_group User.arel_table
        assert_nil query
        u1 = User.new(id: 1, email: 'xbogus', role: 5)
        assert_nil relation.test(u1)
        full_query = relation.build_select
        exp = "SELECT * FROM users ORDER BY users.email ASC LIMIT 100 OFFSET 0"
        assert_equal exp, full_query.to_sql.unquote
      end

      def test_ordering_on_computed_column_works
        relation = get_relation op: :or
        relation[:ordering] = [[:standing, :asc]]
        full_query = relation.build_select
        exp = 'SELECT * FROM users ORDER BY standing ASC LIMIT 100 OFFSET 0'
        assert_equal exp, full_query.to_sql.unquote
      end
    end
  end
end