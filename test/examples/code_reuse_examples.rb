require_relative '../test_helper'
require_relative '../../lib/params_ready'

module ParamsReady
  module Examples
    class CodeReuseExamples < Minitest::Test
      def test_code_reuse_example_with_definition_works
        child = Builder.define_string :child
        parameter = Builder.define_hash :parameter do
          add child
        end
        assert parameter.has_child? :child
      end

      def test_code_reuse_example_with_proc_works
        child_proc = proc do
          add :string, :child
        end
        definition = Builder.define_hash :parameter do
          include &child_proc
        end
        assert definition.has_child? :child
      end

      def test_simple_code_reuse_example_with_proc_works
        local_zero = proc do
          local 0
        end
        definition = Builder.define_integer :parameter do
          include &local_zero
        end
        assert_equal 0, definition.default
        assert_equal true, definition.instance_variable_get(:@local)
      end
    end
  end
end
