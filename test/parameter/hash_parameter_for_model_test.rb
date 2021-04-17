require_relative '../test_helper'
require_relative '../../lib/params_ready/parameter/hash_parameter'
require_relative '../../lib/params_ready/input_context'

module ParamsReady
  module Parameter
    class HashParameterForModelTest < Minitest::Test
      def get_def
        Builder.define_hash :model do
          add :string, :name
          add :integer, :role do
            default 2
            optional
          end
          add :integer, :ranking do
            optional
          end
          add :integer, :owner_id do
            default nil
          end
        end
      end

      def test_all_definite_inputs_are_used_on_create
        input = { name: 'John', role: 4, ranking: 0, owner_id: 1 }
        _, p = get_def.from_input(input)
        exp = input
        assert_equal exp, p.for_model(:create)
      end

      def test_optional_default_is_used_on_create
        input = { name: 'John', ranking: 0, owner_id: 1 }
        _, p = get_def.from_input(input)
        exp = { name: 'John', role: 2, ranking: 0, owner_id: 1 }
        assert_equal exp, p.for_model(:create)
      end

      def test_optional_parameter_used_on_create
        input = { name: 'John', role: 4, owner_id: 1 }
        _, p = get_def.from_input(input)
        exp = { name: 'John', role: 4, ranking: nil, owner_id: 1 }
        assert_equal exp, p.for_model(:create)
      end

      def test_mandatory_default_is_used_on_create
        input = { name: 'John', role: 4, ranking: 0 }
        _, p = get_def.from_input(input)
        exp = { name: 'John', role: 4, ranking: 0, owner_id: nil }
        assert_equal exp, p.for_model(:create)
      end

      def test_all_definite_inputs_are_used_on_update
        input = { name: 'John', role: 4, ranking: 0, owner_id: nil }
        _, p = get_def.from_input(input)
        exp = input
        assert_equal exp, p.for_model(:update)
      end

      def test_optional_default_is_not_used_on_update
        input = { name: 'John', ranking: 0, owner_id: 2 }
        _, p = get_def.from_input(input)
        exp = { name: 'John', ranking: 0, owner_id: 2 }
        assert_equal exp, p.for_model(:update)
      end

      def test_optional_parameter_is_not_used_on_update
        input = { name: 'John', role: 4, owner_id: 2 }
        _, p = get_def.from_input(input)
        exp = { name: 'John', role: 4, owner_id: 2 }
        assert_equal exp, p.for_model(:update)
      end

      def test_mandatory_default_is_used_on_update
        input = { name: 'John', role: 4, ranking: 0 }
        _, p = get_def.from_input(input)
        exp = { name: 'John', role: 4, ranking: 0, owner_id: nil }
        assert_equal exp, p.for_model(:update)
      end
    end
  end
end