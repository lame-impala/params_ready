require_relative 'test_helper'
require_relative 'context_using_parameter_helper'
require_relative '../lib/params_ready/query/relation'
require_relative '../lib/params_ready/output_parameters'
require_relative '../lib/params_ready/input_context'

module ParamsReady
  class OutputParametersTest < Minitest::Test
    def get_relation
      relation = Builder.define_relation(:users, altn: :usrs) do
        add :string, :string, altn: :str do
          constrain :enum, %w(foo bar baz)
          default 'foo'
        end
        add :integer, :number, altn: :num do
          constrain :range, 1..10
          default 5
        end
        add :array, :array, altn: :ary do
          prototype :integer
        end
        add :polymorph, :polymorph, altn: :pm do
          type :string, :simple, altn: :spl do
            default 'default'
          end
          type :hash, :complex, altn: :cpx do
            add :integer, :first, altn: :fst
            add :string, :second, altn: :scd
          end
          identifier :ppt
          default :simple
        end
        paginate(100, 500)
        order do
          column :email, :asc
          column :name, :asc
          column :hits, :desc
          default [:email, :asc], [:name, :asc]
        end
      end
      relation = relation.create
      relation[:string] = 'bar'
      relation[:number] = 3
      relation[:array] = [0, 1, 2]
      relation[:polymorph].set_value(complex: { first: 1, second: 'two' })
      relation
    end

    def test_output_parameters_scopes_work
      relation = get_relation
      d = OutputParameters.decorate(relation.freeze)
      assert_equal 'usrs', d.scoped_name
      assert_equal 'usrs[str]', d[:string].scoped_name
      assert_equal 'usrs[num]', d[:number].scoped_name
      assert_equal 'usrs[ary][0]', d[:array][0].scoped_name
      assert_equal 'usrs[ary][1]', d[:array][1].scoped_name
      assert_equal 'usrs[ary][2]', d[:array][2].scoped_name
      assert_equal 'usrs[pm]', d[:polymorph].scoped_name
      assert_equal 'usrs[pm][cpx]', d[:polymorph][:complex].scoped_name
      assert_equal 'usrs[pm][cpx][fst]', d[:polymorph][:complex][:first].scoped_name
      assert_equal 'usrs[pm][cpx][scd]', d[:polymorph][:complex][:second].scoped_name
      err = assert_raises do
        d[:polymorph][:complex][:second][:other]
      end
      assert_equal "Parameter 'second' doesn't support square brackets access", err.message
      err = assert_raises do
        d[:polymorph][:simple]
      end
      assert_equal "Type 'simple' is not set, current type: 'complex'", err.message
    end

    def test_flat_pairs_work
      relation = get_relation
      d = OutputParameters.decorate(relation.freeze)
      flat = d.flat_pairs
      exp = [
        ["usrs[str]", "bar"],
        ["usrs[num]", "3"],
        ["usrs[ary][0]", "0"],
        ["usrs[ary][1]", "1"],
        ["usrs[ary][2]", "2"],
        ["usrs[ary][cnt]", "3"],
        ["usrs[pm][cpx][fst]", "1"],
        ["usrs[pm][cpx][scd]", "two"]
      ]
      assert_equal exp, flat
    end

    def test_delegating_methods_work
      relation = get_relation
      d = OutputParameters.decorate relation.freeze
      exp = {
        usrs: {
          str: 'bar',
          num: '3',
          ary: { '0' => '0', '1' => '1', '2' => '2', 'cnt' => '3' },
          pm: { cpx: { fst: '1', scd: 'two' }
          }
        }
      }
      assert_equal exp, d.to_hash
      assert_equal({ str: exp[:usrs][:str] }, d[:string].to_hash)
      assert_equal({ pm: exp[:usrs][:pm] }, d[:polymorph].to_hash)
      assert_equal(exp[:usrs][:str], d[:string].unwrap)
      assert_equal([0, 1, 2], d[:array].unwrap)
    end

    def test_to_a_yields_array_of_decorated_objects
      relation = get_relation
      d = OutputParameters.decorate relation.freeze
      ary = d[:array].to_a
      ary.each do |elem|
        assert elem.is_a? OutputParameters
      end
    end

    def test_to_a_raises_if_called_on_non_array_parameter
      relation = get_relation
      d = OutputParameters.decorate relation.freeze
      err = assert_raises(ParamsReadyError) do
        d[:string].to_a
      end
      exp = "Unimplemented method 'to_a' for ParamsReady::Parameter::ValueParameterDefinition"
      assert_equal exp, err.message
    end

    def test_with_to_hash_parameter_is_self_permitted
      intent = Intent.instance(:frontend).permit(:string, :array, polymorph: [complex: [:first]])
      d = OutputParameters.decorate(get_relation.freeze, intent)
      exp = {
        usrs: {
          str: 'bar',
          ary: { '0' => '0', '1' => '1', '2' => '2', 'cnt' => '3' },
          pm: { cpx: { fst: '1' }
          }
        }
      }
      assert_equal exp, d.to_hash
    end

    def test_permissions_work_with_for_output
      intent = Intent.instance(:frontend).permit(:string, :array, polymorph: [complex: [:first]])
      d = OutputParameters.decorate(get_relation.freeze, intent)
      exp = {
        str: 'bar',
        ary: { '0' => '0', '1' => '1', '2' => '2', 'cnt' => '3' },
        pm: { cpx: { fst: '1' }
        }
      }
      assert_equal exp, d.for_output
    end

    def test_permissions_work_with_for_frontend
      intent = Intent.instance(:backend).permit(:string, :array, polymorph: [complex: [:first]])
      d = OutputParameters.decorate(get_relation.freeze, intent)
      exp = {
        str: 'bar',
        ary: { '0' => '0', '1' => '1', '2' => '2', 'cnt' => '3' },
        pm: { cpx: { fst: '1' }
        }
      }
      assert_equal exp, d.for_frontend
    end

    def test_permissions_work_with_for_model
      intent = Intent.instance(:frontend).permit(:string, :array, polymorph: [complex: [:first]])
      d = OutputParameters.decorate(get_relation.freeze, intent)
      exp = {
        string: 'bar',
        array: [0, 1, 2],
        polymorph: { complex: { first: 1 }}
      }
      assert_equal exp, d.for_model
    end

    def test_output_parameter_passes_data_over_to_intent
      _, p = ContextUsingParameter.get_def.from_input({ using_context: 5 })
      p[:using_context] = 6

      data = Builder.define_hash :data do
        add :integer, :dec
      end.from_input({ dec: 1 }).last.freeze

      intent = Intent.new(:frontend, Restriction.blanket_permission, data: data)
      op = OutputParameters.decorate(p.freeze, intent)

      out = op.to_hash
      assert_equal({ param: { using_context: '5' }}, out)
      out = op.for_output
      assert_equal({ using_context: '5' }, out)
      out = op.for_frontend
      assert_equal({ using_context: '5' }, out)
      out = op.for_model
      assert_equal({ using_context: 6 }, out)
    end
  end
end
