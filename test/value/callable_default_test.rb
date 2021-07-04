require_relative '../test_helper'
require_relative '../../lib/params_ready/parameter/value_parameter'
require_relative '../../lib/params_ready/result'

module ParamsReady
  class Global
    def self.previous
      @previous ||= 0
    end

    def self.current
      @current ||= 0
    end

    def self.current=(val)
      @previous = current
      @current = val
    end
  end

  class CallableDefaultTest < Minitest::Test
    def test_callable_default_is_legal
      d = Builder.define_parameter :hash, :test do
        add :integer, :local do
          local Helpers::Callable.new { Global.previous }
        end

        add :integer, :default do
          default Helpers::Callable.new { Global.current }
        end

        add :integer, :standard
      end
      Global.current = 1
      _, p = d.from_input standard: 7
      Global.current = 2
      assert_equal 1, p[:local].unwrap
      assert_equal 2, p[:default].unwrap
    end
  end
end