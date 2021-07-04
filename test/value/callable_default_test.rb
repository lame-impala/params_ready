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
      assert_equal "Invalid default: input '1'/String (expected '1'/Integer)", err.message
      Global.current = 2
      err = assert_raises(ParamsReadyError) do
        p[:default].unwrap
      end
      assert_equal "Invalid default: input '2'/String (expected '2'/Integer)", err.message
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