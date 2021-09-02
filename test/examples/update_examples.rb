require_relative '../test_helper'
require_relative '../../lib/params_ready'

module ParamsReady
  module Examples
    class UpdateExamples < Minitest::Test
      def test_update_if_in_works
        definition = Builder.define_struct :parameter do
          add :struct, :inner do
            add :integer, :a
            add :integer, :b
          end
        end

        _, parameter = definition.from_input({ inner: { a: 5, b: 10 }})
        parameter.freeze
        updated = parameter.update_in(15, [:inner, :b])
        assert_equal 15, updated[:inner][:b].unwrap
      end
    end
  end
end
