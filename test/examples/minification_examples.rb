require_relative '../test_helper'
require_relative '../../lib/params_ready'

module ParamsReady
  module Examples
    class MinificationExamples < Minitest::Test
      def test_minification_example_works
        definition = Builder.define_hash :parameter do
          add :string, :default_parameter do
            default 'FOO'
          end
          add :string, :optional_parameter do
            optional
          end
          add :string, :obligatory_parameter
          add :string, :no_output_parameter do
            no_output
          end
        end

        parameter = definition.create
        parameter[:obligatory_parameter] = 'BAR'
        parameter[:no_output_parameter] = 'BAX'

        expected = { obligatory_parameter: 'BAR' }
        assert_equal expected, parameter.for_output(Intent.instance(:frontend))
        _, from_input = definition.from_input({ obligatory_parameter: 'BAR', no_output_parameter: 'BAX' })
        assert_equal parameter, from_input
      end
    end
  end
end
