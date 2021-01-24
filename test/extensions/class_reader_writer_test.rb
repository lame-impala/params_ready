require_relative '../test_helper'
require_relative '../../lib/params_ready/extensions/class_reader_writer'

module ParamsReady
  module Extensions
    class ClassReaderWriterTest < Minitest::Test
      class A
        extend ClassReaderWriter
        class_reader_writer :foo
        foo 'FOO'
      end

      class B < A; end
      class C < A
        foo 'BAR'
      end

      def test_ancestor_chain_lookup_works
        assert_equal 'FOO', A.foo
        assert_equal 'FOO', B.foo
        assert_equal 'BAR', C.foo
      end

      def test_value_allowed_to_be_set_once
        err = assert_raises do
          A.foo 'BAR'
        end
        exp = "Class variable '@foo' already set for 'ParamsReady::Extensions::ClassReaderWriterTest::A'"
        assert_equal exp, err.message
      end
    end
  end
end
