require_relative '../test_helper'
require_relative '../../lib/params_ready/parameter/value_parameter'
require_relative '../../lib/params_ready/result'
require_relative '../../lib/params_ready/value/validator'

module ParamsReady
  class IntegerParameterTest < MiniTest::Test
    def integer_def(default: Extensions::Undefined, optional: false)
      Builder.define_integer :number, altn: :nm do
        constrain :range, 1..5
        self.default(default) unless default == Extensions::Undefined
        self.optional if optional
      end
    end

    def get_param(**options)
      definition = integer_def **options
      definition.create
    end

    def test_raises_when_coercion_fails_without_validator
      iparam = get_param(default: 1)
      exp = assert_raises do
        iparam.set_value "bogus"
      end
      assert_equal("can't coerce 'bogus' into Integer", exp.message)
    end

    def test_writes_error_to_result_if_validator_avaliable_on_failed_coercion
      iparam = get_param(default: 1)
      validator = Result.new(iparam.name)
      result = iparam.set_value "bogus", Format.instance(:frontend), validator
      refute result.ok?
      exp = "errors for number\n"
      exp += "can't coerce 'bogus' into Integer"
      assert_equal(exp, result.error_messages)
    end

    def test_raises_when_validation_fails_without_validator
      iparam = get_param(default: 1)
      exp = assert_raises do
        iparam.set_value 6
      end
      assert_equal("value '6' not in range", exp.message)
    end

    def test_writes_error_to_result_if_validator_avaliable_on_failed_validation
      iparam = get_param(default: 1)
      validator = Result.new(iparam.name)
      result = iparam.set_value 6, Format.instance(:frontend), validator
      refute result.ok?
      exp = "errors for number\n"
      exp += "value '6' not in range"
      assert_equal(exp, result.error_messages)
      assert_equal Extensions::Undefined, iparam.instance_variable_get(:@value)
      assert_equal 1, iparam.unwrap
    end

    def test_value_is_set_with_correct_input
      iparam = get_param(default: 1)
      validator = Result.new(iparam.name)
      result = iparam.set_value 5, Format.instance(:frontend), validator
      assert result.ok?
      assert_equal(5, iparam.unwrap)
    end

    def test_default_is_used_on_value_missing
      iparam = get_param(default: 1)
      assert_equal(1, iparam.unwrap)
    end

    def test_no_default_parameter_raises_on_missing_value_without_validator
      iparam = get_param
      exp = assert_raises do
        iparam.set_value nil, nil
      end
      assert_equal("number: value is nil", exp.message)
    end

    def test_no_default_parameter_writes_error_to_result_on_missing_value_with_validator
      iparam = get_param
      validator = Result.new(iparam.name)
      result = iparam.set_value nil, Format.instance(:frontend), validator
      refute(result.ok?)
      assert_equal("number: value is nil", result.errors['number'][0].message)
    end

    def test_no_default_parameter_returns_nil_on_missing_value_for_optional_parameter
      iparam = get_param optional: true
      validator = Result.new(iparam.name)
      result = iparam.set_value nil, Format.instance(:frontend), validator
      assert(result.ok?)
      assert_nil(iparam.unwrap)
    end

    def test_correctly_set_parameter_writes_to_hash_if_eligible
      sparam = get_param
      sparam.set_value 3
      assert_equal({number: 3}, sparam.to_hash_if_eligible)
      assert_equal({nm: 3}, sparam.to_hash_if_eligible(Intent.instance(:alternative_only)))
    end

    def test_optional_parameter_writes_to_hash_if_eligible_if_value_nil
      sparam = get_param optional: true
      sparam.set_value nil
      assert_nil(sparam.to_hash_if_eligible(Intent.instance(:minify_only)))
      assert_equal({nm: nil}, sparam.to_hash_if_eligible(Intent.instance(:alternative_only)))
    end
  end
end