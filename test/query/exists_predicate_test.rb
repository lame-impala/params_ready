require_relative '../test_helper'
require_relative '../../lib/params_ready/query/exists_predicate'
require_relative '../../lib/params_ready/value/validator'

module ParamsReady
  module Query
    class ExistsPredicateTest < Minitest::Test
      def get_definition(
        grouping_optional: false,
        grouping_default: Extensions::Undefined,
        outer_table: nil,
        existence: nil
      )
        builder = ExistsPredicateBuilder.instance :subscription_exists, altn: :sbs, coll: :subscriptions
        builder.instance_eval do
          outer_table outer_table unless outer_table.nil?
          arel_table Subscription.arel_table
          operator do
            local :and
          end
          fixed_operator_predicate :valid_equal, altn: :vld_eq, attr: :valid do
            operator :equal
            type :value, :boolean do
              default true
            end
          end
          fixed_operator_predicate :channel_equal, altn: :cnl_eq, attr: :channel do
            operator :equal
            type :value, :integer do
              optional
            end
          end
          related on: :id, eq: :users_id

          optional() if grouping_optional
          default(grouping_default) unless grouping_default == Extensions::Undefined

          unless existence.nil?
            existence do
              default existence
            end
          end
        end
        builder.build
      end

      def get_predicate(*args, **opts)
        get_definition(*args, **opts).create
      end

      def test_predicate_can_be_optional
        predicate = get_predicate grouping_optional: true
        assert_nil predicate.unwrap
        assert_nil predicate.to_hash_if_eligible(Intent.instance(:frontend))
        assert_equal({ subscription_exists: nil }, predicate.to_hash_if_eligible(Intent.instance(:backend)))
        assert_nil predicate.to_query_if_eligible(:whatever, context: Restriction.blanket_permission)
        assert_nil predicate.test(:whatever)
      end

      def test_predicate_can_have_default
        predicate = get_predicate grouping_default: { valid_equal: true, channel_equal: 3 }
        assert_nil predicate.to_hash_if_eligible(Intent.instance(:frontend))
        op = GroupingOperator.instance(:and)
        exp = { subscription_exists: { operator: op, valid_equal: true, channel_equal: 3 }}
        assert_equal(exp, predicate.to_hash_if_eligible(Intent.instance(:backend)))
        assert_equal({ operator: op, valid_equal: true, channel_equal: 3 }, predicate.unwrap)

        exp = <<~SQL
          EXISTS (SELECT * FROM subscriptions
          WHERE (subscriptions.valid = 1 AND subscriptions.channel = 3)
          AND (users.id = subscriptions.users_id)
          LIMIT 1)
        SQL
        query = predicate.to_query User.arel_table
        assert_equal exp.unformat, query.to_sql.unquote
      end

      def test_exists_predicate_produces_correct_sql
        pre = get_predicate
        pre[:channel_equal] = 5
        query = pre.to_query User.arel_table

        exp = <<~SQL
          EXISTS (SELECT * FROM subscriptions
          WHERE (subscriptions.valid = 1 AND subscriptions.channel = 5)
          AND (users.id = subscriptions.users_id)
          LIMIT 1)
        SQL
        assert_equal exp.unformat, query.to_sql.unquote
      end

      def test_exist_not_predicate_produces_correct_sql
        pre = get_predicate existence: :none
        pre[:channel_equal] = 5
        query = pre.to_query User.arel_table

        exp = <<~SQL
          NOT (EXISTS (SELECT * FROM subscriptions
          WHERE (subscriptions.valid = 1 AND subscriptions.channel = 5)
          AND (users.id = subscriptions.users_id)
          LIMIT 1))
        SQL
        assert_equal exp.unformat, query.to_sql.unquote
      end

      def test_existence_can_be_set_dynamically
        d = get_definition existence: :some
        hash = { subscription_exists: { existence: :none, operator: :and, valid_equal: true, channel_equal: 2 }}
        _, pre = d.from_hash hash, context: Format.instance(:backend)
        query = pre.to_query User.arel_table

        exp = <<~SQL
          NOT (EXISTS (SELECT * FROM subscriptions
          WHERE (subscriptions.valid = 1 AND subscriptions.channel = 2)
          AND (users.id = subscriptions.users_id)
          LIMIT 1))
        SQL
        assert_equal exp.unformat, query.to_sql.unquote
      end

      def test_exists_predicate_uses_outer_table_if_defined
        pre = get_predicate outer_table: User.arel_table
        pre[:channel_equal] = 5
        query = pre.to_query Profile.arel_table

        exp = <<~SQL
          EXISTS (SELECT * FROM subscriptions
          WHERE (subscriptions.valid = 1 AND subscriptions.channel = 5)
          AND (users.id = subscriptions.users_id)
          LIMIT 1)
        SQL
        assert_equal exp.unformat, query.to_sql.unquote
      end

      def test_exists_predicate_test_works
        pre = get_predicate
        pre[:channel_equal] = 5

        bad = [
          Subscription.new(valid: false, channel: 5),
          Subscription.new(valid: true, channel: 2)
        ]
        u1 = User.new(id: 1, email: 'not@having.cz', role: :user, subscriptions: bad)
        refute pre.test u1
        good = [
          Subscription.new(valid: true, channel: 5),
          Subscription.new(valid: false, channel: 2)
        ]
        u2 = User.new(id: 2, email: 'having@one.cz', role: :user, subscriptions: good)
        assert pre.test u2
      end

      def test_not_exists_predicate_test_works
        pre = get_predicate existence: :none
        pre[:channel_equal] = 5

        good = [
          Subscription.new(valid: false, channel: 5),
          Subscription.new(valid: true, channel: 2)
        ]
        u1 = User.new(id: 1, email: 'not@having.cz', role: :user, subscriptions: good)

        assert pre.test u1
        bad = [
          Subscription.new(valid: true, channel: 5),
          Subscription.new(valid: false, channel: 2)
        ]
        u2 = User.new(id: 2, email: 'having@one.cz', role: :user, subscriptions: bad)
        refute pre.test u2
      end

      def test_exist_predicate_with_single_predicate_in_subquery_doesnt_require_operator
        d = ExistsPredicateBuilder.instance(:subscription_exists).include do
          arel_table Subscription.arel_table
          fixed_operator_predicate :valid_equal, altn: :vld_eq, attr: :valid do
            operator :equal
            type :value, :boolean do
              default false
            end
          end
          related do
            on(:id).eq(:users_id)
          end
          optional
        end.build

        _, ep = d.from_hash({ subscription_exists: { valid_equal: true }}, context: Format.instance(:backend))

        assert_equal({ subscription_exists: { valid_equal: true }}, ep.to_hash_if_eligible(Intent.instance(:backend)))
        exp = <<~SQL
          EXISTS (SELECT * FROM subscriptions
          WHERE (subscriptions.valid = 1)
          AND (users.id = subscriptions.users_id)
          LIMIT 1)
        SQL

        query = ep.to_query User.arel_table
        assert_equal exp.unformat, query.to_sql.unquote
      end
    end
  end
end