require_relative '../test_helper'
require_relative '../../lib/params_ready'

module ParamsReady
  module Examples
    class PolymorphExamples < Minitest::Test
      def test_polymorph_example_works
        polymorph_id = Builder.define_polymorph :polymorph_id do
          type :integer, :numeric_id do
            default 0
          end
          type :string, :literal_id
        end.create

        polymorph_id.set_value numeric_id: 1
        assert_equal({ polymorph_id: { numeric_id: 1 }}, polymorph_id.to_hash)

        type = polymorph_id.type
        assert_equal(1, polymorph_id[type].unwrap)
      end
    end
  end
end
