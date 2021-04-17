require_relative '../test_helper'
require_relative '../../lib/params_ready'

module ParamsReady
  module Examples
    class AlternativeNameExamples < Minitest::Test
      def test_alternative_name_example_works
        definition = Builder.define_hash :parameter, altn: :p do
          add :string, :name, altn: :n
        end
        _, parameter = definition.from_input({ n: 'FOO' })
        assert_equal({ name: 'FOO' }, parameter.unwrap)

        context = :backend # or Format.instance(:backend)
        _, parameter = definition.from_input({ name: 'BAR' }, context: context)
        assert_equal({ name: 'BAR' }, parameter.unwrap)

        hash = parameter.for_model(:create)
        assert_equal({ name: 'BAR' }, hash)
        hash = parameter.for_output :backend
        assert_equal({ name: 'BAR' }, hash)
        hash = parameter.for_frontend
        assert_equal({ n: 'BAR' }, hash)
        hash = parameter.for_output :frontend
        assert_equal({ n: 'BAR' }, hash)
      end

      def test_output_parameters_example_works
        definition = Builder.define_hash :complex, altn: :cpx do
          add :string, :string_parameter, altn: :sp
          add :array, :array_parameter, altn: :ap do
            prototype :integer
          end
        end

        _, parameter = definition.from_input({ sp: 'FOO', ap: [1, 2] })

        output_parameters = OutputParameters.new parameter.freeze, :frontend

        assert_equal 'cpx', output_parameters.scoped_name
        assert_equal 'cpx', output_parameters.scoped_id
        assert_equal 'cpx[sp]', output_parameters[:string_parameter].scoped_name
        assert_equal 'cpx_sp', output_parameters[:string_parameter].scoped_id
        assert_equal 'cpx[ap][0]', output_parameters[:array_parameter][0].scoped_name
        assert_equal 'cpx_ap_0', output_parameters[:array_parameter][0].scoped_id
        assert_equal 'cpx[ap][cnt]', output_parameters[:array_parameter][:cnt].scoped_name
        assert_equal 'cpx_ap_cnt', output_parameters[:array_parameter][:cnt].scoped_id

        exp = [["cpx[sp]", "FOO"], ["cpx[ap][0]", "1"], ["cpx[ap][1]", "2"], ["cpx[ap][cnt]", "2"]]
        assert_equal exp, output_parameters.flat_pairs
      end

      def test_alternative_mapping_example_works
        definition = Builder.define_hash :parameter do
          add :string, :remapped, altn: [:path, :to, :string]
        end

        input = { path: { to: { string: 'FOO' }}}

        _, parameter = definition.from_input(input)
        assert_equal 'FOO', parameter[:remapped].unwrap
        assert_equal input, parameter.for_output(:frontend)
      end

      def test_mapping_example_works
        definition = Builder.define_hash :parameter do
          add :string, :foo
          add :string, :bar
          add :integer, :first
          add :integer, :second


          map [:strings, [:Foo, :Bar]] => [[:foo, :bar]]
          map [:integers, [:First, :Second]] => [[:first, :second]]
        end

        input = { strings: { Foo: 'FOO', Bar: 'BAR' }, integers: { First: 1, Second: 2 }}
        _, parameter = definition.from_input(input, context: :json)
        assert_equal 'FOO', parameter[:foo].unwrap
        assert_equal 'BAR', parameter[:bar].unwrap
        assert_equal 1, parameter[:first].unwrap
        assert_equal 2, parameter[:second].unwrap
        assert_equal input, parameter.for_output(:json)
      end
    end
  end
end
