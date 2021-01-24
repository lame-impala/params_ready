require_relative '../test_helper'
require_relative '../../lib/params_ready'

module ParamsReady
  module Examples
    class DefinitionExamples < Minitest::Test
      def test_from_hash_method_works
        definition = Builder.define_integer :ranking do
          default 0
        end

        context = InputContext.new(:frontend, data: {})
        result, param = definition.from_input(1, context: context)
        if result.ok?
          param.freeze
          assert_equal 1, param.unwrap
        else
          # Error handling here
        end
      end
    end
  end
end
