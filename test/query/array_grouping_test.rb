require_relative '../test_helper'
require_relative '../../lib/params_ready/query/polymorph_predicate'
require_relative '../../lib/params_ready/query/fixed_operator_predicate'
require_relative '../../lib/params_ready/query/variable_operator_predicate'
require_relative '../../lib/params_ready/query/array_grouping'

module ParamsReady
  module Query
    class ArrayGroupingTest < Minitest::Test
      def get_definition(
        grouping_operator: :and,
        optional: nil,
        predicate_default: Extensions::Undefined,
        grouping_default: Extensions::Undefined
      )
        builder = ArrayGroupingBuilder.instance(:grouping, altn: :grp)
        builder.instance_eval do
          prototype :polymorph_predicate, :polymorph, altn: :pm do
            type :fixed_operator_predicate, :email_like, altn: :eml_lk, attr: :email do
              operator :like
              type :value, :string do
                default('Default') if predicate_default == :email_like
              end
            end
            type :variable_operator_predicate, :role_variable_operator, altn: :rl_vop, attr: :role do
              operators :equal, :greater_than_or_equal, :less_than_or_equal
              type :value, :integer
              default({ op: :eq, val: 0 }) if predicate_default == :role_variable_operator
            end
            default(predicate_default) unless predicate_default == Extensions::Undefined
          end
          operator do
            default grouping_operator
          end
        end
        builder.optional if optional
        builder.default(grouping_default) unless grouping_default == Extensions::Undefined
        builder.build
      end

      def get_predicate(**opts)
        definition = get_definition(**opts)
        definition.create
      end

      def test_predicate_can_be_optional
        definition = get_definition(optional: true)
        _, predicate = definition.from_hash({})
        assert_nil predicate.to_hash_if_eligible(Intent.instance(:frontend))
        assert_equal({ grouping: nil }, predicate.to_hash_if_eligible(Intent.instance(:backend)))
        assert_nil predicate.unwrap
        assert_nil predicate.to_query_if_eligible(:whatever, context: Restriction.blanket_permission)
        assert_nil predicate.test(:whatever)
      end

      def test_predicate_can_have_default
        default = {
          array: [{ email_like: 'bogus' }, role_variable_operator: { operator: :equal, value: 10 }],
          operator: :and
        }
        definition = get_definition(grouping_default: default)
        _, predicate = definition.from_hash({})

        assert_nil predicate.to_hash_if_eligible(Intent.instance(:frontend))
        eq = PredicateRegistry.operator(:equal, Format.instance(:backend))

        and_op = GroupingOperator.instance(:and)
        be = {
          grouping: {
            array: [
              { email_like: "bogus" },
              { role_variable_operator: { operator: eq, value: 10 }}
            ],
            operator: and_op
          }
        }

        assert_equal be, predicate.to_hash_if_eligible(Intent.instance(:backend))
        assert_equal be[:grouping], predicate.unwrap
        sql = predicate.to_query(User.arel_table).to_sql.unquote
        assert_equal "(users.email LIKE '%bogus%' AND users.role = 10)", sql
        u1 = User.new(id: 2, email: 'bogus', role: 10)
        u2 = User.new(id: 2, email: 'other', role: 10)
        u3 = User.new(id: 2, email: 'bogus', role: 5)
        assert predicate.test(u1)
        refute predicate.test(u2)
        refute predicate.test(u3)
      end

      def test_delegating_parameter_works
        predicate = get_predicate

        predicate.set_value(
          array: [
            role_variable_operator: {
              value: 10, operator: :greater_than_or_equal
            }
          ], operator: :and
        )
        clone = predicate.dup
        assert_equal clone, predicate
        assert clone.is_definite?
        refute clone.is_nil?
        refute clone.is_undefined?
        refute clone.is_default?
        gteq = PredicateRegistry.operator :greater_than_or_equal, Format.instance(:backend)

        be = {
          array: [
            {
              role_variable_operator: {
                operator: gteq,
                value: 10
              }
            }
          ],
          operator: GroupingOperator.instance(:and)
        }

        fe = {
          a: {
            '0' => {
              rl_vop: {
                op: :gteq,
                val: '10'
              }
            },
            'cnt' => '1'
          }
        }

        assert_equal(be, clone.unwrap)
        assert_equal(fe, clone.format(Intent.instance(:frontend)))
        new_value = { grp: { a: [rl_vop: { op: gteq, val: 5 }], op: :and }}
        clone.set_from_hash(new_value, context: Format.instance(:frontend))
        new_value[:grp][:op] = GroupingOperator.instance(:and)
        assert_equal(new_value[:grp], clone.format(Intent.instance(:alternative_only)))
      end

      def test_to_query_works
        predicate = get_predicate
        predicate.set_value(value1)
        assert_equal "(users.email LIKE '%bogus%' AND users.role >= 10)", predicate.to_query(User.arel_table).to_sql.unquote
        predicate.set_value(value2)
        assert_equal "(users.email LIKE '%bogus%' OR users.role >= 10)", predicate.to_query(User.arel_table).to_sql.unquote
        predicate.set_value(value3)
        assert_equal '(users.role <= 10)', predicate.to_query(User.arel_table).to_sql.unquote
      end

      def test_test_works
        good = User.new(id: 2, email: 'bogus@example.com', role: 10)
        soso = User.new(id: 1, email: 'bad@example.com', role: 10)
        bad = User.new(id: 1, email: 'bad@example.com', role: 3)
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
        d = get_definition predicate_default: :email_like
        p = Builder.define_parameter :struct, :parameter, altn: :p do
          add d
        end.create
        p.set_value(grouping: value1)
        al = Restriction.permit(array: [:email_like, :role_variable_operator])
        dl = Restriction.prohibit

        with_query_context restrictions: [al, dl] do |context|
          q = p[:grouping].to_query(User.arel_table, context: context).to_sql.unquote
          assert_equal "(users.email LIKE '%bogus%' AND users.role >= 10)", q
        end

        int = Intent.instance(:backend).permit(grouping: [{ array: [:email_like] }])
        dec = OutputParameters.decorate(p.freeze, int)

        dump = dec.for_output
        assert_equal({ grouping: { array: [{ email_like: "bogus" }, nil]}}, dump)
        al = Restriction.permit(array: [:email_like])
        dl = Restriction.prohibit(array: [:role_variable_operator])
        with_query_context restrictions: [al, dl] do |context|
          assert_equal "(users.email LIKE '%bogus%')", p[:grouping].to_query(User.arel_table, context: context).to_sql.unquote
        end
      end

      def value1
        {
          array: [{ email_like: 'bogus' }, role_variable_operator: { operator: :greater_than_or_equal, value: 10 }],
          operator: :and
        }
      end

      def value2
        {
          array: [{ email_like: 'bogus' }, role_variable_operator: { operator: :greater_than_or_equal, value: 10 }],
          operator: :or
        }
      end

      def value3
        {
          array: [role_variable_operator: { operator: :less_than_or_equal, value: 10 }],
          operator: :and
        }
      end
    end
  end
end