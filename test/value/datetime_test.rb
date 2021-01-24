require_relative '../test_helper'
require_relative '../../lib/params_ready/parameter/value_parameter'
require_relative '../../lib/params_ready/result'
require_relative '../../lib/params_ready/value/validator'


module ParamsReady
  class DateTimeParameterTest < MiniTest::Test
    def datetime_def
      earlier = DateTime.parse('2020-9-01T00:00:00')
      later = DateTime.parse('2020-10-01T00:00:00')
      Builder.define_datetime :datetime, altn: :dtt do
        constrain :range, earlier..later
      end
    end

    def test_raises_when_coercion_fails_without_validator
      dtparam = datetime_def.create
      exp = assert_raises do
        dtparam.set_value "bogus"
      end
      assert_equal("can't coerce 'bogus' into DateTime", exp.message)
    end

    def test_writes_error_to_result_if_validator_avaliable_on_failed_coercion
      dtparam = datetime_def.create
      validator = Result.new(dtparam.name)
      result = dtparam.set_value "bogus", Format.instance(:frontend), validator
      refute result.ok?
      exp = "errors for datetime\n"
      exp += "can't coerce 'bogus' into DateTime"
      assert_equal(exp, result.error_messages)
      assert_equal Extensions::Undefined, (dtparam.instance_variable_get :@value)
    end

    def test_raises_when_validation_fails_without_validator
      dtparam = datetime_def.create
      dt = DateTime.parse('2020-08-01T00:00:00')

      exp = assert_raises do
        dtparam.set_value dt
      end
      assert_equal("value '#{dt}' not in range", exp.message)
    end

    def test_writes_error_to_result_if_validator_avaliable_on_failed_validation
      dtparam = datetime_def.create
      validator = Result.new(dtparam.name)
      dt = DateTime.parse('2020-08-01T00:00:00')

      result = dtparam.set_value dt, Format.instance(:frontend), validator
      refute result.ok?
      exp = "errors for datetime\n"
      exp += "value '#{dt}' not in range"
      assert_equal(exp, result.error_messages)
      assert_equal Extensions::Undefined, dtparam.instance_variable_get(:@value)
    end

    def test_can_be_set_with_datetime_object
      dtparam = datetime_def.create
      validator = Result.new(dtparam.name)
      dt = DateTime.parse('2020-09-15T00:00:00')
      result = dtparam.set_value dt, Format.instance(:frontend), validator
      assert result.ok?
      assert_equal(dt, dtparam.unwrap)
    end

    def test_can_be_set_with_time_object
      dtparam = datetime_def.create
      validator = Result.new(dtparam.name)
      dt = DateTime.parse('2020-09-15T00:00:00')
      t = dt.to_time
      result = dtparam.set_value t, Format.instance(:frontend), validator
      assert result.ok?
      assert_equal(dt, dtparam.unwrap)
    end

    def test_coerces_from_integer
      dtparam = datetime_def.create
      validator = Result.new(dtparam.name)
      dt = DateTime.parse('2020-09-15T00:00:00')
      int = dt.to_time.to_i
      result = dtparam.set_value int, Format.instance(:frontend), validator
      assert result.ok?
      assert_equal(dt, dtparam.unwrap)
    end

    def test_parses_from_string
      dtparam = datetime_def.create
      validator = Result.new(dtparam.name)
      str = '2020-09-15T00:00:00'
      dt = DateTime.parse(str)
      result = dtparam.set_value str, Format.instance(:frontend), validator
      assert result.ok?
      assert_equal(dt, dtparam.unwrap)
    end
  end
end