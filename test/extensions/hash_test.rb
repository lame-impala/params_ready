require_relative '../test_helper'
require_relative '../../lib/params_ready/extensions/hash'

module ParamsReady
  module ExtensionsTest
    class StringKeyTest < Minitest::Test
      def test_returns_value_if_key_is_string
        h = { 'key' => 'FOO' }
        assert_equal 'FOO', Extensions::Hash.indifferent_access(h, 'key', 'NULL')
      end

      def test_returns_value_if_key_is_symbol
        h = { key: 'FOO' }
        assert_equal 'FOO', Extensions::Hash.indifferent_access(h, 'key', 'NULL')
      end

      def test_returns_default_if_key_absent
        h = { other: 'FOO' }
        assert_equal 'NULL', Extensions::Hash.indifferent_access(h, 'key', 'NULL')
      end
    end

    class SymbolKeyTest < Minitest::Test
      def test_returns_value_if_key_is_string
        h = { 'key' => 'FOO' }
        assert_equal 'FOO', Extensions::Hash.indifferent_access(h, :key, 'NULL')
      end

      def test_returns_value_if_key_is_symbol
        h = { key: 'FOO' }
        assert_equal 'FOO', Extensions::Hash.indifferent_access(h, :key, 'NULL')
      end

      def test_returns_default_if_key_absent
        h = { other: 'FOO' }
        assert_equal 'NULL', Extensions::Hash.indifferent_access(h, :key, 'NULL')
      end
    end

    class IntegerKeyTest < Minitest::Test
      def test_returns_value_if_key_is_integer
        h = { 0 => 'FOO' }
        assert_equal 'FOO', Extensions::Hash.indifferent_access(h, 0, 'NULL')
      end

      def test_returns_value_if_key_is_string
        h = { '0' => 'FOO' }
        assert_equal 'FOO', Extensions::Hash.indifferent_access(h, 0, 'NULL')
      end

      def test_returns_value_if_key_is_symbol
        h = { '0': 'FOO' }
        assert_equal 'FOO', Extensions::Hash.indifferent_access(h, 0, 'NULL')
      end

      def test_returns_default_if_key_absent
        h = { other: 'FOO' }
        assert_equal 'NULL', Extensions::Hash.indifferent_access(h, 0, 'NULL')
      end
    end
  end
end
