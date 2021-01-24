require_relative '../test_helper'
require_relative '../../lib/params_ready/parameter/value_parameter'
require_relative '../../lib/params_ready/result'

module ParamsReady
  class BooleanParameterTest < MiniTest::Test
    def boolean_def(default: false, optional: false)
      Builder.define_boolean :boolean, altn: :bool do
        self.default(default) unless default == Extensions::Undefined
        self.optional if optional
      end
    end

    class Translator
      def self.t(value)
        case value
        when true then 'YES'
        when false then 'NO'
        else
          'NULL'
        end
      end
    end

    def test_helper_can_be_added
      p = Builder.define_boolean :with_helper do
        helper :display_value do |t|
          t.t(unwrap)
        end
      end.create
      p.set_value true
      assert_equal 'YES', p.display_value(Translator)
    end

    def test_helper_can_not_override_existing_method
      err = assert_raises do
        Builder.define_boolean :with_helper do
          helper :method do
            puts 'This should not be possible'
          end
        end.create
      end
      assert_equal "Helper 'method' overrides existing method", err.message
    end

    def test_raises_when_coercion_fails_without_validator
      bparam = boolean_def.create
      exp = assert_raises do
        bparam.set_value "bogus"
      end
      assert_equal("can't coerce 'bogus' into Boolean", exp.message)
    end

    def test_writes_error_to_result_if_validator_avaliable_on_failed_coercion
      bparam = boolean_def.create
      validator = Result.new(bparam.name)
      result = bparam.set_value "bogus", Format.instance(:frontend), validator
      refute result.ok?
      exp = "errors for boolean\n"
      exp += "can't coerce 'bogus' into Boolean"
      assert_equal(exp, result.error_messages)
    end

    def test_sets_value_with_boolean_object
      bparam = boolean_def.create
      validator = Result.new(bparam.name)
      result = bparam.set_value true, Format.instance(:frontend), validator
      assert result.ok?
      assert_equal(true, bparam.unwrap)
    end

    def test_uses_default_when_value_missing
      bparam = boolean_def.create
      assert_equal(false, bparam.unwrap)
    end

    def test_raises_on_missing_value_without_validator_if_no_default_defined
      bparam = boolean_def(default: Extensions::Undefined).create
      exp = assert_raises do
        bparam.set_value nil, nil
      end
      assert_equal("boolean: value is nil", exp.message)
    end

    def test_writes_error_to_result_on_missing_value_with_validator_if_no_defaul_defined
      bparam = boolean_def(default: Extensions::Undefined).create
      validator = Result.new(bparam.name)
      result = bparam.set_value nil, Format.instance(:frontend), validator
      refute(result.ok?)
      assert_equal("boolean: value is nil", result.errors["boolean"][0].message)
    end
  end
end