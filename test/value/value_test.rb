require_relative '../test_helper'
require_relative '../../lib/params_ready/value/custom'

module ParamsReady
  module Value
    class IntegerValueTest < Minitest::Test
      def test_integer_is_succesfully_coerced
        assert_equal(1, IntegerCoder.try_coerce(1, Format.instance(:backend)))
      end
  
      def test_valid_string_is_succesfully_coerced
        assert_equal(2, IntegerCoder.try_coerce('2', Format.instance(:frontend)))
      end
  
      def test_invalid_string_raises
        e = assert_raises do
          IntegerCoder.try_coerce('a2', Format.instance(:frontend))
        end
        assert_equal("can't coerce 'a2' into Integer", e.message)
      end
    end
  
    class BooleanValueTest < Minitest::Test
      def test_boolean_is_succesfully_coerced
        assert_equal(true, BooleanCoder.try_coerce(true, Format.instance(:backend)))
        assert_equal(false, BooleanCoder.try_coerce(false, Format.instance(:backend)))
      end
  
      def test_valid_string_is_succesfully_coerced
        assert_equal(true, BooleanCoder.try_coerce('true', Format.instance(:frontend)))
        assert_equal(false, BooleanCoder.try_coerce('false', Format.instance(:frontend)))
      end
  
      def test_invalid_string_raises
        e = assert_raises do
          BooleanCoder.try_coerce('x', Format.instance(:frontend))
        end
        assert_equal("can't coerce 'x' into Boolean", e.message)
      end
    end
  
    class NilReturningCoderTest < Minitest::Test
      class DefaultStringCoder < StringCoder
        def self.coerce(value, context)
          string = super
          return 'Default' if string.empty?
  
          string
        end
      end
      Parameter::ValueParameterBuilder.register_coder :default_string, DefaultStringCoder
  
      def test_optional_parameter_set_to_nil_if_coder_returns_nil
        d = Builder.define_non_empty_string :optional_string do
          optional
        end
  
        _, param = d.from_hash({ optional_string: '' })
        assert_nil param.unwrap
      end
  
      def test_nil_value_is_not_subject_to_constraint_in_optional_parameter
        d = Builder.define_non_empty_string :optional_string do
          optional
          constrain :enum, %w[A B C]
        end
  
        _, param = d.from_hash({ optional_string: '' })
        assert_nil param.unwrap
      end
  
      def test_default_having_parameter_set_to_default_if_coder_returns_nil
        d = Builder.define_non_empty_string :default_string do
          default 'SOME'
        end
  
        _, param = d.from_hash({ default_string: '' })
        assert_equal 'SOME', param.unwrap
      end
  
      def test_nil_default_is_not_subject_to_constraint
        d = Builder.define_non_empty_string :optional_string do
          constrain :enum, %w[FOO BAR]
          default nil
        end
  
        _, param = d.from_hash({ optional_string: '' })
        assert_nil param.unwrap
      end
  
      def test_non_optional_non_default_parameter_raises_if_coder_return_nil
        d = Builder.define_non_empty_string(:regular_string)
        err = assert_raises do
          d.from_hash({ regular_string: '' })
        end
        assert_equal 'regular_string: value is nil', err.message
      end
  
      def test_coder_default_is_subject_to_constraint_for_input
        d = Builder.define_default_string :default_string do
          constrain :enum, %w[A B C]
        end
  
        r, _ = d.from_hash({ default_string: '' })

        assert_equal "errors for default_string -- value 'Default' not in enum", r.error.message
      end
  
      def test_coder_default_is_subject_to_constraint_for_default
        err = assert_raises do
          Builder.define_default_string :default_string do
            constrain :enum, %w[A B C]
            default ''
          end.create
        end
        assert_equal "Invalid default: input '' (String) coerced to 'Default' (String)", err.message
      end
    end
  end
end