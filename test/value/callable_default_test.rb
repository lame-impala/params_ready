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

    def self.raising
      raise 'BOO!'
    end

    def self.string
      @string ||= 'foo'
    end
  end

  class CallableDefaultTest < Minitest::Test
    def get_def(local_d, default_d)
      Builder.define_parameter :struct, :test do
        add :integer, :local do
          local Helpers::Callable.new &local_d
        end

        add :integer, :default do
          constrain :range, 1..5
          default Helpers::Callable.new &default_d
        end

        add :integer, :standard
      end
    end

    def test_sets_default_on_first_read
      d = get_def(proc { Global.previous }, proc { Global.current })
      Global.current = 1
      _, p = d.from_input standard: 7
      Global.current = 2
      assert_equal 1, p[:local].unwrap
      assert_equal 2, p[:default].unwrap
      Global.current = 3
      assert_equal 1, p[:local].unwrap
      assert_equal 2, p[:default].unwrap
    end

    def test_sets_default_on_unwrap
      d = get_def(proc { Global.previous }, proc { Global.current })
      Global.current = 1
      _, p = d.from_input standard: 7
      Global.current = 2
      exp = { local: 1, default: 2, standard: 7 }
      assert_equal exp, p.unwrap
      Global.current = 3
      assert_equal exp, p.unwrap
    end

    def test_sets_default_on_freeze
      d = Builder.define_parameter :string, :str do
        default ParamsReady::Helpers::Callable.new { Global.string }
      end
      _, p = d.from_input(nil)
      p.freeze
      assert_equal Global.string, p.unwrap
      assert p.unwrap.frozen?
      refute Global.string.frozen?
    end

    def test_default_canonicality_checked
      d = get_def(proc { Global.not_canonical }, proc { Global.not_canonical })
      Global.current = 1
      _, p = d.from_input standard: 7
      err = assert_raises(ParamsReadyError) do
        p[:local].unwrap
      end
      assert_equal "Invalid default: input '1'/String (expected '1'/Integer)", err.message
      Global.current = 2
      err = assert_raises(ParamsReadyError) do
        p[:default].unwrap
      end
      assert_equal "Invalid default: input '2'/String (expected '2'/Integer)", err.message
    end

    def test_constraints_applied_to_default
      d = get_def(proc { Global.previous }, proc { Global.current })
      _, p = d.from_input standard: 7
      Global.current = 6
      err = assert_raises(ParamsReadyError) do
        p[:default].unwrap
      end
      assert_equal "Invalid default: value '6' not in range", err.message
    end

    def test_raises_propietary_error_if_callable_fails
      d = get_def(proc { Global.raising }, proc { Global.raising })
      Global.current = 1
      _, p = d.from_input standard: 7
      err = assert_raises(ParamsReadyError) do
        p[:local].unwrap
      end
      assert_equal "Invalid default: BOO!", err.message
    end

    def test_duplicates_default
      d = Builder.define_parameter :string, :str do
        default ParamsReady::Helpers::Callable.new { Global.string }
      end
      _, p = d.from_input(nil)
      assert_equal Global.string, p.unwrap
      assert_equal Global.string.object_id, Global.string.object_id
      refute_equal Global.string.object_id, p.unwrap.object_id
    end
  end
end