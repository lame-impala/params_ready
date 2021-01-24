require_relative '../test_helper'
require_relative '../../lib/params_ready'

module ParamsReady
  module Examples
    class StateAccessorsExample < Minitest::Test
      def test_state_accessors_work_with_optional_parameter
        param = Builder.define_integer(:role) do
          optional
        end.create
        assert param.is_undefined?
        assert param.is_nil?
        refute param.is_definite?
        assert_nil param.unwrap
        assert_equal 7, param.unwrap_or(7)

        param.set_value nil
        refute param.is_undefined?
        assert param.is_nil?
        refute param.is_definite?
        assert_nil param.unwrap
        assert_equal 7, param.unwrap_or(7)

        param.set_value 10
        refute param.is_undefined?
        refute param.is_nil?
        assert param.is_definite?
        assert_equal 10, param.unwrap
        assert_equal 10, param.unwrap_or(7)
      end

      def test_state_accessors_work_with_default_nil
        param = Builder.define_integer(:role) do
          default nil
        end.create

        refute param.is_undefined?
        assert param.is_nil?
        refute param.is_definite?
        assert_nil param.unwrap
        assert_equal 7, param.unwrap_or(7)


        param.set_value nil
        refute param.is_undefined?
        assert param.is_nil?
        refute param.is_definite?
        assert_nil param.unwrap
        assert_equal 7, param.unwrap_or(7)

        param.set_value 10
        refute param.is_undefined?
        refute param.is_nil?
        assert param.is_definite?
        assert_equal 10, param.unwrap
        assert_equal 10, param.unwrap_or(7)
      end

      def test_state_accessors_work_with_definite_default
        param = Builder.define_integer(:role) do
          default 5
        end.create
        refute param.is_undefined?
        refute param.is_nil?
        assert param.is_definite?
        assert_equal 5, param.unwrap
        assert_equal 5, param.unwrap_or(7)

        param.set_value nil
        refute param.is_undefined?
        refute param.is_nil?
        assert param.is_definite?
        assert_equal 5, param.unwrap
        assert_equal 5, param.unwrap_or(7)

        param.set_value 10
        refute param.is_undefined?
        refute param.is_nil?
        assert param.is_definite?
        assert_equal 10, param.unwrap
        assert_equal 10, param.unwrap_or(7)
      end

      def test_state_accessors_work_with_non_optional_non_default_parameter
        param = Builder.define_integer(:role).create

        assert param.is_undefined?
        refute param.is_nil?
        refute param.is_definite?
        err = assert_raises do
          param.unwrap
        end
        assert err.is_a?(ValueMissingError)
        assert_equal 7, param.unwrap_or(7)

        err = assert_raises do
          param.set_value nil
        end
        assert err.is_a?(ValueMissingError)

        param.set_value 10
        refute param.is_undefined?
        refute param.is_nil?
        assert param.is_definite?
        assert_equal 10, param.unwrap
        assert_equal 10, param.unwrap_or(7)
      end
    end
  end
end