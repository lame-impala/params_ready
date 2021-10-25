require_relative '../test_helper'
require_relative '../../lib/params_ready/query/join_clause'

module ParamsReady
  module Query
    class ConditionalJoinTest < Minitest::Test
      def get_relation_definition
        subscriptions = Subscription.arel_table
        subscription_count = subscriptions.group(:user_id)
                                          .project(subscriptions[:user_id].sum.as('sum'), subscriptions[:user_id])
                                          .as('subscription_counts')
        Builder.define_relation(:users) do
          model User
          join_table subscription_count, :inner do
            on(:id).eq(:user_id)
            only_if { |context, _parameter| context[:join] }
          end
          fixed_operator_predicate :num_subscriptions, attr: :sum do
            operator :greater_than_or_equal
            type :value, :integer
            optional
          end
          operator { local :and }
        end
      end

      def test_table_is_joined_if_condition_met
        d = get_relation_definition
        _, r = d.from_input(num_subscriptions: 5)
        context = QueryContext.new(Restriction.blanket_permission, { join: true })
        arel = r.build_select(context: context)
        expected = <<~SQL.squish
          SELECT * FROM "users" 
          INNER JOIN 
            (SELECT SUM("subscriptions"."user_id") AS sum, "subscriptions"."user_id" FROM "subscriptions" GROUP BY user_id) subscription_counts 
          ON "users"."id" = subscription_counts."user_id" WHERE ("users"."sum" >= 5)
        SQL
        assert_equal expected, arel.to_sql
      end

      def test_table_is_not_joined_if_condition_unmet
        d = get_relation_definition
        _, r = d.from_input(num_subscriptions: nil)
        context = QueryContext.new(Restriction.blanket_permission, { join: false })
        arel = r.build_select(context: context)
        expected = <<~SQL.squish
          SELECT * FROM "users" 
        SQL
        assert_equal expected, arel.to_sql
      end
    end
  end
end