require_relative '../test_helper'
require_relative '../../lib/params_ready/query/variable_operator_predicate'
require_relative '../../lib/params_ready/input_context'
require_relative '../../lib/params_ready/query_context'
require_relative '../../lib/params_ready/result'

module ParamsReady
  module Query
    class VariableOperatorPredicateDelegationTest < Minitest::Test
      def test_calls_to_builder_delegated_to_hash_parameter_builder
        d = VariableOperatorPredicateBuilder.instance(:role).include do
          operators :equal, :less_than_or_equal, :greater_than_or_equal

          type :value, :integer do
            constrain :enum, [1, 2, 4, 8, 16]
          end
          default({ operator: :less_than_or_equal, value: 8 })
          map [:nested, [:operator]] => [[:op]]
          map [[:value]] => [[:val]]

          postprocess do |parameter, context|
            max = context[:current_user][:role] || 4
            next if parameter[:value].unwrap <= max

            parameter[:value].set_value max
          end
        end.build

        _, p = d.from_input({}, context: InputContext.new(:frontend, { current_user: { role: 4 }}))
        # default set correctly:
        assert_equal :less_than_or_equal, p[:operator].unwrap.name
        # postprocess applied:
        assert_equal 4, p[:value].unwrap

        _, p = d.from_input({ nested: { operator: :eq }, value: 8 }, context: InputContext.new(:json, { current_user: { role: 4 }}))
        # mapping applied:
        assert_equal 4, p[:value].unwrap
        assert_equal :equal, p[:operator].unwrap.name
      end
    end

    class VariableOperatorPredicateWithDynamicalyResolvedSelectExpressionTest < Minitest::Test
      def test_variable_operator_predicate_with_literal_column_expression_works
        literal = '(SELECT count(id) FROM subscriptions WHERE subscriptions.user_id = users.id)'

        d = VariableOperatorPredicateBuilder.instance(:num_subs).include do
          arel_table :none
          operators :less_than_or_equal, :greater_than_or_equal
          type :value, :integer

          attribute(name: :num_subscriptions, expression: literal)
        end.build

        _, p = d.from_hash({ num_subs: { op: :gteq, val: 10 }})
        exp = "(SELECT count(id) FROM subscriptions WHERE subscriptions.user_id = users.id) >= 10"
        context = Restriction.blanket_permission
        query = p.to_query(User.arel_table, context: context)
        assert_equal exp, query.to_sql.unquote
        aliased = p.alias_select_expression(User.arel_table, context)
        exp = "(SELECT count(id) FROM subscriptions WHERE subscriptions.user_id = users.id) AS num_subscriptions"
        assert_equal(exp, aliased.to_sql.unquote)
      end

      def test_variable_operator_predicate_with_block_column_expression_works
        d = VariableOperatorPredicateBuilder.instance(:num_subs).include do
          arel_table :none
          operators :less_than_or_equal, :greater_than_or_equal
          type :value, :integer

          attribute(name: :num_subscriptions) do |_arel_table, context, _parameter|
            <<~SQL
              (SELECT count(id)
               FROM subscriptions
               WHERE subscriptions.user_id = users.id
               AND subscriptions.valid_to <= '#{context[:date]}')
            SQL
          end
        end.build

        _, p = d.from_hash({ num_subs: { op: :gteq, val: 10 }})
        date = Date.parse('2020-06-21')
        exp = <<~SQL
          (SELECT count(id)
           FROM subscriptions
           WHERE subscriptions.user_id = users.id
           AND subscriptions.valid_to <= '#{date}')
           >= 10
        SQL
        al = Restriction.blanket_permission
        context = QueryContext.new(al, { date: date })
        query = p.to_query(User.arel_table, context: context)
        assert_equal exp.unformat, query.to_sql.unquote.gsub("\n", '')
      end
    end

    class VariableOperatorPredicateTest < Minitest::Test
      def get_predicate_definition(
        name, altn, type, operators,
        optional: nil,
        default: Extensions::Undefined,
        attribute: nil,
        table: nil
      )
        builder = VariableOperatorPredicateBuilder.instance "#{name}_variable_operator", altn: "#{altn}_vop", attr: attribute || name
        builder.instance_eval do
          arel_table table || User.arel_table
          operators(*operators)
          type(:value, type)
          optional() if optional
          default(default, **{}) unless default == Extensions::Undefined
        end
        builder.build
      end

      def get_predicate(*args, **opts)
        get_predicate_definition(*args, **opts).create
      end

      def test_operator_can_have_default
        d = VariableOperatorPredicateBuilder.instance(:with_default).include do
          operators :equal, :like do
            default :equal
          end

          type :value, :string do
            default 'FOO'
          end
        end.build
        _, p = d.from_hash({})

        exp = { with_default: { operator: :equal, value: 'FOO' }}
        assert_equal exp, p.to_hash(:marshal_only)
      end

      def test_predicate_can_be_optional
        d = get_predicate_definition(:email, :eml, :string, [:equal, :like], optional: true)
        _, predicate = d.from_hash({})
        assert_nil predicate.to_hash_if_eligible(Intent.instance(:frontend))
        assert_equal({ email_variable_operator: nil }, predicate.to_hash_if_eligible(Intent.instance(:backend)))
        assert_nil predicate.unwrap
        assert_nil predicate.to_query_if_eligible(:whatever, context: Restriction.blanket_permission)
        assert_nil predicate.test(:whatever)
      end

      def test_predicate_can_have_default
        d = get_predicate_definition(:email, :eml, :string, [:equal, :like], default: { operator: :equal, value: 'default@value.com' })
        _, predicate = d.from_hash({})
        assert_nil predicate.to_hash_if_eligible(Intent.instance(:frontend))
        eq = PredicateRegistry.operator(:eq, Format.instance(:frontend))
        assert_equal({ email_variable_operator: { operator: eq, value: 'default@value.com' }}, predicate.to_hash_if_eligible(Intent.instance(:backend)))
        assert_equal({ operator: eq, value: 'default@value.com' }, predicate.unwrap)
        assert_equal '"users"."email" = \'default@value.com\'', predicate.to_query(User).to_sql
        u = User.new(id: 2, email: 'default@value.com', role: 'client')
        assert predicate.test(u)
      end


      def non_optional_non_default_predicate(table: nil)
        get_predicate(
          :audience,
          :aud,
          :integer,
          [:equal, :less_than, :greater_than],
          table: table
        )
      end

      def test_delegating_parameter_works
        predicate = non_optional_non_default_predicate
        predicate.set_value(value: 10, operator: :greater_than)
        clone = predicate.dup
        assert_equal clone, predicate
        assert clone.is_definite?
        refute clone.is_nil?
        refute clone.is_undefined?
        refute clone.is_default?
        gt = PredicateRegistry.operator :greater_than, Format.instance(:backend)
        assert_equal({ operator: gt, value: 10 }, clone.unwrap)
        assert_equal({ op: :gt, val: '10' }, clone.format(Intent.instance(:frontend)))
        assert_equal({ audience_variable_operator: { operator: gt, value: 10 }}, clone.to_hash_if_eligible)
        clone.set_from_hash({ audience_variable_operator: { operator: gt, value: 5 }}, context: Format.instance(:backend))
        assert_equal({ operator: gt, value: 5 }, clone.unwrap)
      end

      def test_custom_identifier_can_be_set
        d = get_predicate_definition(
          :email,
          :eml,
          :string,
          [:equal, :like],
          attribute: :email
        )
        _, predicate = d.from_hash({ eml_vop: { val: 'bogus', op: :lk }})
        clone = predicate.dup
        lk = PredicateRegistry.operator :like, Format.instance(:backend)
        assert_equal({ operator: lk, value: 'bogus' }, clone.unwrap)
        assert_equal({ email_variable_operator: { operator: lk, value: 'bogus' }}, clone.to_hash_if_eligible)
        clone.set_from_hash({ email_variable_operator: { operator: :equal, value: 'a@b.cz' }}, context: Format.instance(:backend))
        eq = PredicateRegistry.operator :equal, Format.instance(:backend)
        assert_equal({ eml_vop: { op: :eq, val: 'a@b.cz' }}, clone.to_hash_if_eligible(Intent.instance(:frontend)))
      end

      def test_to_query_works
        predicate = non_optional_non_default_predicate
        predicate.set_value(value: 10, operator: :greater_than)
        assert_equal '"users"."audience" > 10', predicate.to_query(User).to_sql
        predicate.set_value(value: 3, operator: :equal)
        assert_equal '"users"."audience" = 3', predicate.to_query(User).to_sql
        predicate.set_value(value: 7, operator: :less_than)
        assert_equal '"users"."audience" < 7', predicate.to_query(User).to_sql
      end

      def test_to_query_works_with_arel_table_none
        predicate = non_optional_non_default_predicate table: :none
        predicate.set_value(value: 10, operator: :greater_than)
        assert_equal 'audience > 10', predicate.to_query(User).to_sql
        predicate.set_value(value: 3, operator: :equal)
        assert_equal 'audience = 3', predicate.to_query(User).to_sql
        predicate.set_value(value: 7, operator: :less_than)
        assert_equal 'audience < 7', predicate.to_query(User).to_sql
      end

      def test_test_works
        big = User.new(id: 1, email: 'big.audience@example.com', role: 'user', audience: 50)
        small = User.new(id: 2, email: 'small.audience@example.com', role: 'user', audience: 10)
        predicate = non_optional_non_default_predicate
        predicate.set_value(value: 10, operator: :greater_than)

        assert predicate.test(big)
        refute predicate.test(small)
        predicate.set_value(value: 50, operator: :less_than)
        refute predicate.test(big)
        assert predicate.test(small)
        predicate.set_value(value: 10, operator: :equal)
        refute predicate.test(big)
        assert predicate.test(small)
      end

      def test_altn_operator_name_rejected_with_backend_intent
        predicate = non_optional_non_default_predicate
        exp = assert_raises do
          predicate.set_value(value: 10, operator: :eq)
        end
        assert_equal "can't coerce 'eq' into Operator", exp.message
      end
    end
  end
end