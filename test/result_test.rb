require_relative 'test_helper'
require_relative '../lib/params_ready/result'
require_relative '../lib/params_ready/value/coder'
require_relative '../lib/params_ready/value/validator'

module ParamsReady
  class ResultTest < Minitest::Test
    def test_error_reporting_works
      r = Result.new(:users)
      assert(r.ok?)
      error = CoercionError.new 'five', 'integer'
      r.error!(error)
      refute(r.ok?)
      assert_equal("errors for users\n#{error}", r.error_messages)
    end

    def test_reporting_from_child_works
      ru = Result.new(:users)
      rp = ru.for_child(:posts)
      assert(ru.ok?)
      assert(rp.ok?)
      error = Result::Error.new "value 'string' doesn't meet constraints"
      rp.error!(error)
      refute(ru.ok?)
      refute(rp.ok?)
      assert_equal("errors for users.posts\n#{error.message}", ru.error_messages)
    end

    def test_child_errors_make_parent_not_ok
      ru = Result.new(:users)
      rp = ru.for_child(:posts)
      rn = rp.for_child(:number)

      error = Result::Error.new "value 'number' doesn't meet constraints"
      rn.error!(error)
      refute(rn.ok?)
      refute(rp.ok?)
      refute(ru.ok?)

      assert_equal("errors for users.posts.number\n#{error.message}", ru.error_messages)
    end

    def test_result_merging_works
      ru = Result.new(:users)
      rp1 = ru.for_child(:posts)
      rp2 = ru.for_child(:posts)
      error1 = Result::Error.new "value 'string' doesn't meet constraints"
      rp1.error!(error1)
      error2 = CoercionError.new 'ten', 'integer'
      rp2.error!(error2)
      assert_equal("errors for users.posts\n#{error1.message}\n#{error2.message}", ru.error_messages)
    end

    def test_result_merging_works_in_depth
      error1 = Result::Error.new "value 'string' doesn't meet constraints"
      error2 = CoercionError.new 'ten', 'integer'
      error3 = Result::Error.new "value for 'bool' not found"
      error4 = Value::Constraint::Error.new "value 'february' for 'date' doesn't meet constraints"
      ru = Result.new(:users)
      rp1 = ru.for_child(:posts)
      rp2 = ru.for_child(:posts)
      ru.error! error1
      rp1.error! error2
      ru.error! error3
      rp2.error! error4
      exp = "errors for users\n#{error1.message}\n#{error3.message}"
      exp << "\nerrors for users.posts\n#{error2.message}\n#{error4.message}"
      assert_equal exp, ru.error_messages
    end

    def test_errors_are_ordered_by_scope
      ru = Result.new(:users)
      error0 = Result::Error.new "value for 'bool' not found"
      rp1 = ru.for_child(:posts)
      rp2 = ru.for_child(:posts)
      cnt = ru.for_child(:control)
      assert ru.ok?
      assert rp1.ok?
      assert rp2.ok?
      assert cnt.ok?
      error1 = Result::Error.new "value 'string' doesn't meet constraints"
      rp1.error!(error1)
      refute ru.ok?
      refute rp1.ok?
      refute rp2.ok?

      assert cnt.ok?
      error2 = CoercionError.new 'ten', 'integer'
      rp2.error!(error2)
      ru.error! error0
      assert cnt.ok?
      exp = "errors for users\n#{error0.message}"
      exp << "\nerrors for users.posts\n#{error1.message}\n#{error2.message}"

      assert_equal(exp, ru.error_messages)
    end
  end
end
