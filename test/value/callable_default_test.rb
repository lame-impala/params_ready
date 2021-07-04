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

    def self.not_canonical
      current.to_s
    end
  end

  class CallableDefaultTest < Minitest::Test
    def get_def(local_d, default_d)
      Builder.define_parameter :hash, :test do
        add :integer, :local do
          local Helpers::Callable.new &local_d
        end

        add :integer, :default do
          default Helpers::Callable.new &default_d
        end

        add :integer, :standard
      end
    end

    def test_default_canonicality_checked
      d = get_def(proc { Global.not_canonical }, proc { Global.not_canonical })
      Global.current = 1
      _, p = d.from_input standard: 7
      err = assert_raises(ParamsReadyError) do
        p[:local].unwrap
      end
      assert_equal "input '1' (String) coerced to '1' (Integer)", err.message
      Global.current = 2
      err = assert_raises(ParamsReadyError) do
        p[:default].unwrap
      end
      assert_equal "input '2' (String) coerced to '2' (Integer)", err.message
    end

    def test_callable_default_is_legal
      d = get_def(proc { Global.previous }, proc { Global.current })
      Global.current = 1
      _, p = d.from_input standard: 7
      Global.current = 2
      assert_equal 1, p[:local].unwrap
      assert_equal 2, p[:default].unwrap
    end
  end
end