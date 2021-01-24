require_relative '../test_helper'
require_relative '../../lib/params_ready/query/join_clause'

module ParamsReady
  module Query
    class JoinTest < Minitest::Test
      def assert_condition(expected, join)
        arel = join.to_arel(User.arel_table, {}, {}).join_sources[0]
        sql = arel.to_sql.unquote.gsub('LEFT OUTER JOIN subscriptions ON ', '')
        assert_equal(expected, sql)
      end

      def test_column_against_column_works
        join = Join.new(Subscription.arel_table, :outer) do
          on(:id).eq(:subscriber_id)
        end
        assert_condition('users.id = subscriptions.subscriber_id', join)
      end

      def test_expression_against_column_works
        join = Join.new(Subscription.arel_table, :outer) do
          on('users.id', arel_table: :none).eq(:subscriber_id)
        end

        assert_condition('users.id = subscriptions.subscriber_id', join)
      end

      def test_column_against_expression_works
        join = Join.new(Subscription.arel_table, :outer) do
          on(:id).eq('subscriptions.subscriber_id', arel_table: :none)
        end

        assert_condition('users.id = subscriptions.subscriber_id', join)
      end

      def test_column_against_value_works
        join = Join.new(Subscription.arel_table, :outer) do
          on(:id).eq(:subscriber_id)
          on(:subscriber_type, arel_table: Subscription.arel_table)
            .eq("'User'", arel_table: :none)
        end

        exp = "users.id = subscriptions.subscriber_id AND subscriptions.subscriber_type = 'User'"
        assert_condition(exp, join)
      end

      def test_single_expression_works
        join = Join.new(Subscription.arel_table, :outer) do
          on("users.id = subscriptions.subscriber_id", arel_table: :none)
          on("subscriptions.subscriber_type = 'User'", arel_table: :none)
        end

        exp = "(users.id = subscriptions.subscriber_id) AND (subscriptions.subscriber_type = 'User')"
        assert_condition(exp, join)
      end

      def test_proc_against_proc_works
        join = Join.new(Subscription.arel_table, :outer) do
          on(proc { |table, _ctx, _param| table[:id] })
            .eq(proc { |table, _ctx, _param| table[:subscriber_id] })
        end

        assert_condition('users.id = subscriptions.subscriber_id', join)
      end

      def test_proc_returning_symbol_works
        join = Join.new(Subscription.arel_table, :outer) do
          on(proc { |table, _ctx, _param| :id })
            .eq(proc { |table, _ctx, _param| :subscriber_id  })
        end

        assert_condition('users.id = subscriptions.subscriber_id', join)
      end

      def test_grouping_defined_as_proc_returning_string_works
        join = Join.new(Subscription.arel_table, :outer) do
          on(proc { |_table, _ctx, _param| 'users.id = subscriptions.subscriber_id' })
        end

        assert_condition('(users.id = subscriptions.subscriber_id)', join)
      end
    end
  end
end