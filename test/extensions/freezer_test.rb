require_relative '../test_helper'
require_relative '../../lib/params_ready/extensions/freezer'

module ParamsReady
  module Extensions
    class FreezerTest < Minitest::Test
      class F
        attr_reader :count
        def initialize
          @count = 0
        end

        def freeze
          @count += 1
          super
        end
      end

      class A
        extend Freezer
        include Freezer::InstanceMethods

        attr_reader :var_a
        freeze_variable :var_a
        def initialize
          @var_a = F.new
        end
      end

      class B < A; end

      class C < B
        attr_reader :var_c
        freeze_variable :var_c
        def initialize
          super
          @var_c = F.new
        end
      end

      class D < C; end

      def test_all_variables_frozen_exactrly_once
        d = D.new
        assert_equal 0, d.var_a.count
        assert_equal 0, d.var_c.count
        d.freeze
        assert d.frozen?
        assert d.var_a.frozen?
        assert d.var_c.frozen?
        assert_equal 1, d.var_a.count
        assert_equal 1, d.var_c.count
      end
    end
  end
end