require_relative '../test_helper'
require_relative '../../lib/params_ready/query/relation.rb'

module ParamsReady
  module Query
    class OuterJoinTest < Minitest::Test
      def get_definition
        Builder.define_relation(:users, altn: :usr) do
          model User
          join_table Subscription.arel_table, :outer do
            on(:id).eq(:user_id)
          end
          join_table Profile.arel_table, :outer do
            on(:id).eq(:user_id)
          end
          nullness_predicate :subscriptions_id_is_null, altn: :sub_id_is_nl, attr: :id do
            arel_table Subscription.arel_table
            associations :subscriptions
          end
          fixed_operator_predicate :email_like, altn: :eml_lk, attr: :email do
            operator :like
            arel_table User.arel_table
            type :value, :string do
              optional
            end
          end
          operator do
            default :and
          end
          paginate(100, 500)
          order do
            column :email, :asc
            column :channel, :asc, arel_table: Subscription.arel_table
            default [:channel, :asc], [:email, :asc]
          end
        end
      end

      def get_relation
        relation = get_definition.create
        relation
      end

      def test_join_works_when_all_predicates_set
        relation = get_relation
        relation[:email_like] = 'bogus'
        relation[:subscriptions_id_is_null].set_value(false)
        full_query = relation.build_select

        exp = <<~SQL
          SELECT * FROM users 
          LEFT OUTER JOIN subscriptions ON users.id = subscriptions.user_id
          LEFT OUTER JOIN profiles ON users.id = profiles.user_id
          WHERE (NOT (subscriptions.id IS NULL) AND users.email LIKE '%bogus%')
          ORDER BY subscriptions.channel ASC,
          users.email ASC LIMIT 100 OFFSET 0
        SQL

        assert_equal exp.unformat, full_query.to_sql.unquote
      end


      def test_restriction_works
        relation = get_relation
        relation[:email_like] = 'bogus'
        relation[:subscriptions_id_is_null].set_value(false)

        exp = <<~SQL
          SELECT * FROM users 
          LEFT OUTER JOIN subscriptions ON users.id = subscriptions.user_id
          LEFT OUTER JOIN profiles ON users.id = profiles.user_id
          WHERE (users.email LIKE '%bogus%')
          ORDER BY subscriptions.channel ASC,
          users.email ASC LIMIT 100 OFFSET 0
        SQL

        al = Restriction.permit(:email_like, :ordering)
        dl = Restriction.prohibit(:subscriptions_id_is_null)

        with_query_context restrictions: [al, dl] do |context|
          full_query = relation.build_select(context: context)
          assert_equal exp.unformat, full_query.to_sql.unquote
        end
      end

      def test_test_on_association_works
        relation = get_relation
        relation[:email_like] = 'bogus'

        s1 = Subscription.new(valid: true, channel: 1)
        good = User.new(id: 1, email: 'bogus@email.com', role: 1, subscriptions: [s1])
        assert relation.test(good)

        bad = User.new(id: 2, email: 'other@email.com', role: 1, subscriptions: [])
        refute relation.test(bad)
      end

      def test_to_hash_if_eligible_works
        relation = get_relation
        relation[:email_like] = 'bogus'
        relation[:subscriptions_id_is_null].set_value(false)
        hash = relation.to_hash_if_eligible(Intent.instance(:marshal_alternative))
        exp = {
          usr: {
            sub_id_is_nl: 'false',
            eml_lk: 'bogus',
            op: 'and',
            pgn:  '0-100',
            ord: 'channel-asc|email-asc'
          }
        }
        assert_equal exp, hash
      end

      def test_from_hash_works
        d = get_definition
        hash = {
          usr: {
            eml_lk: 'bogus',
            sub_id_is_nl: false,
            op: 'or',
            pgn:  '100-50',
            ord: 'channel-desc'
          }
        }
        _, relation = d.from_hash(hash)
        assert_equal 'bogus', relation[:email_like].unwrap
        assert_equal false, relation[:subscriptions_id_is_null].unwrap
        assert_equal :or, relation[:operator].unwrap.type
        assert_equal 100, relation.offset
        assert_equal 50, relation.limit
        assert_equal [[:channel, :desc]], relation.ordering.to_array
      end
    end
  end
end