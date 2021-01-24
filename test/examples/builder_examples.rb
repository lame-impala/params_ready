require_relative '../test_helper'
require_relative '../../lib/params_ready'

module ParamsReady
  module Examples
    class BuilderExamples < Minitest::Test
      def test_defining_builder_using_instance_works
        builder = Parameter::ValueParameterBuilder.instance :ranking, :integer
        builder.default 0
        definition = builder.build
        assert_equal :ranking, definition.name
        assert_equal 0, definition.default
        assert_equal Value::IntegerCoder, definition.coder
      end

      def test_defining_builder_using_convenience_method_works
        definition = Builder.define_integer :ranking do
          default 0
        end
        param = definition.create
        assert_equal :ranking, param.name
      end
    end
  end
end
