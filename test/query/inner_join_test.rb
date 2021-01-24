require_relative '../test_helper'
require_relative '../../lib/params_ready/query/relation.rb'

module ParamsReady
  module Query
    class InnerJoinTest < Minitest::Test
      def get_relation_definition
        definition = Builder.define_relation(:subscription, altn: :sub) do
          model Subscription
          join_table User.arel_table, :inner do
            on(:user_id).eq(:id)
          end
          fixed_operator_predicate :valid_equal, altn: :vld_eq, attr: :valid do
            operator :equal
            type :value, :boolean do
              local true
            end
          end
          fixed_operator_predicate :user_email_like, altn: :user_eml_lk, attr: :email do
            operator :like
            arel_table User.arel_table
            associations :user
            type :value, :string do
              optional
            end
          end
          operator do
            default :and
          end
          paginate(100, 500)
          order do
            column :email, :asc, arel_table: User.arel_table
            column :channel, :asc
            default [:email, :asc], [:channel, :asc]
          end
        end
      end

      def get_relation
        relation = get_relation_definition.create
        relation
      end

      def test_join_works_when_all_predicates_set
        relation = get_relation
        relation[:user_email_like] = 'bogus'
        full_query = relation.build_select

        exp = <<~SQL
          SELECT * FROM subscriptions INNER JOIN users
          ON subscriptions.user_id = users.id
          WHERE (subscriptions.valid = 1 AND users.email LIKE '%bogus%')
          ORDER BY users.email ASC,
          subscriptions.channel ASC LIMIT 100 OFFSET 0
        SQL

        assert_equal exp.unformat, full_query.to_sql.unquote
      end

      def test_test_on_association_works
        relation = get_relation
        relation[:user_email_like] = 'bogus'

        good = User.new(id: 1, email: 'bogus@email.com', role: 1)
        s1 = Subscription.new(valid: true, channel: 1, user: good)
        assert relation.test(s1)

        bad = User.new(id: 2, email: 'other@email.com', role: 1)
        s2 = Subscription.new(valid: true, channel: 1, user: bad)
        refute relation.test(s2)
      end

      def test_to_hash_if_eligible_works
        relation = get_relation
        relation[:user_email_like] = 'bogus'
        hash = relation.to_hash_if_eligible(Intent.instance(:marshal_alternative))
        exp = {
          sub: {
            vld_eq: 'true',
            user_eml_lk: 'bogus',
            op: 'and',
            pgn:  '0-100',
            ord: 'email-asc|channel-asc'
          }
        }
        assert_equal exp, hash
      end

      def test_from_hash_works
        definition = get_relation_definition
        hash = {
          sub: {
            user_eml_lk: 'bogus',
            op: 'or',
            pgn:  '100-50',
            ord: 'channel-desc'
          }
        }
        _, relation = definition.from_hash(hash)
        assert_equal 'bogus', relation[:user_email_like].unwrap
        assert_equal :or, relation[:operator].unwrap.type
        assert_equal 100, relation.offset
        assert_equal 50, relation.limit
        assert_equal [[:channel, :desc]], relation.ordering.to_array
      end
    end
  end
end