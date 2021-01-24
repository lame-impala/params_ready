require_relative '../test_helper'
require_relative '../../lib/params_ready/parameter/value_parameter'
require_relative '../../lib/params_ready/result'
require_relative '../../lib/params_ready/value/validator'

module ParamsReady
  class DateParameterTest < MiniTest::Test
    def date_def
      past = Date.today - 3
      future = Date.today + 3
      Builder.define_date :date, altn: :dt do
        constrain :range, past..future
      end
    end

    def test_raises_when_coercion_fails_without_validator
      dparam = date_def.create
      exp = assert_raises do
        dparam.set_value "bogus"
      end
      assert_equal("can't coerce 'bogus' into Date", exp.message)
    end

    def test_writes_error_to_result_if_validator_avaliable_on_failed_coercion
      dparam = date_def.create
      validator = Result.new(dparam.name)
      result = dparam.set_value "bogus", Format.instance(:frontend), validator
      refute result.ok?
      exp = "errors for date\n"
      exp += "can't coerce 'bogus' into Date"
      assert_equal(exp, result.error_messages)
      assert_equal Extensions::Undefined, (dparam.instance_variable_get :@value)
    end

    def test_raises_when_validation_fails_without_validator
      dparam = date_def.create
      d = Date.today - 10

      exp = assert_raises do
        dparam.set_value d
      end
      assert_equal("value '#{d}' not in range", exp.message)
    end

    def test_writes_error_to_result_if_validator_avaliable_on_failed_validation
      dparam = date_def.create
      validator = Result.new(dparam.name)
      d = Date.today - 10
      result = dparam.set_value d, Format.instance(:frontend), validator
      refute result.ok?
      exp = "errors for date\n"
      exp += "value '#{d}' not in range"
      assert_equal(exp, result.error_messages)
      assert_equal Extensions::Undefined, dparam.instance_variable_get(:@value)
    end

    def test_value_is_set_with_correct_date_object
      dparam = date_def.create
      validator = Result.new(dparam.name)
      d = Date.today
      result = dparam.set_value d, Format.instance(:frontend), validator
      assert result.ok?
      assert_equal(d, dparam.unwrap)
    end

    def test_value_is_set_with_time_object
      dparam = date_def.create
      validator = Result.new(dparam.name)
      d = Date.today
      t = d.to_time
      result = dparam.set_value t, Format.instance(:frontend), validator
      assert result.ok?
      assert_equal(d, dparam.unwrap)
    end

    def test_value_is_set_with_integer
      dparam = date_def.create
      validator = Result.new(dparam.name)
      d = Date.today
      int = d.to_time.to_i
      result = dparam.set_value int, Format.instance(:frontend), validator
      assert result.ok?
      assert_equal(d, dparam.unwrap)
    end

    def test_value_is_set_with_string
      dparam = date_def.create
      validator = Result.new(dparam.name)
      d = Date.today
      s = d.to_s
      result = dparam.set_value s, Format.instance(:frontend), validator
      assert result.ok?
      assert_equal(d, dparam.unwrap)
    end

    def test_value_marshalled_if_format_marshals_date
      _, dparam = date_def.from_input Date.today
      f = Format.new(marshal: { only: [:date] }, naming_scheme: :standard, remap: :false, omit: [], local: false)
      assert dparam.format(f).is_a? String
    end

    def test_value_not_marshalled_unless_format_marshals_date
      _, dparam = date_def.from_input Date.today
      f = Format.new(marshal: { only: [:value] }, naming_scheme: :standard, remap: :false, omit: [], local: false)
      assert dparam.format(f).is_a?(Date)
    end
  end
end