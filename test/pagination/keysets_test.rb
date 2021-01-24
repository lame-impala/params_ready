require_relative '../test_helper'
require_relative '../../lib/params_ready/pagination/keysets'

module ParamsReady
  module Pagination
    class BeforeKeysetsTest < Minitest::Test
      def test_returns_true_nil_if_empty_and_delta_zero
        bc = BeforeKeysets.new []
        assert_nil bc.page(0, 10)
      end

      def test_returns_false_nil_if_empty_and_delta_non_zero
        bc = BeforeKeysets.new []
        assert_nil bc.page(1, 10)
      end

      def test_returns_true_first_if_non_empty_and_delta_zero
        bc = BeforeKeysets.new [2, 1]
        assert_equal 2, bc.page(0, 10)
      end

      def test_returns_true_one_before_shift_if_non_empty_and_shift_greater_or_equal_length
        bc = BeforeKeysets.new [11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1]
        assert_equal 1, bc.page(1, 10)
      end

      def test_returns_true_nil_if_non_empty_and_shift_less_or_equal_length_and_page_exists
        bc = BeforeKeysets.new [10, 9, 8, 7, 6, 5, 4, 3, 2, 1]
        assert_equal({}, bc.page(1, 10))
      end

      def test_returns_true_nil_if_non_empty_and_shift_less_or_equal_length_and_page_exists_not
        bc = BeforeKeysets.new [10, 9, 8, 7, 6, 5, 4, 3, 2, 1]
        assert_nil bc.page(2, 10)
      end

      def test_skips_block_if_raw_nil
        ac = BeforeKeysets.new [2, 1] do |raw|
          { id: raw }
        end
        page = ac.page(2, 10)
        assert_nil page
      end

      def test_uses_block_to_transform_raw_result
        ac = BeforeKeysets.new [2, 1] do |raw|
          { id: raw }
        end
        page = ac.page(0, 10)
        assert_equal({ id: 2 }, page)
      end
    end

    class AfterKeysetsTest < Minitest::Test
      def test_returns_false_nil_if_length_zero
        ac = AfterKeysets.new 10, []
        assert_nil ac.page(1, 10)
      end

      def test_returns_true_last_for_first_page_if_length_one
        ac = AfterKeysets.new 10, [11]
        page = ac.page(1, 10)
        assert_equal 10, page
      end

      def test_returns_false_nil_for_second_page_if_length_equal_limit
        ac = AfterKeysets.new 10, [11, 12, 13, 14, 15, 16, 17, 18, 19, 20]
        assert_nil ac.page(2, 10)
      end

      def test_returns_false_second_last_for_second_page_if_length_equal_limit_plus_one
        ac = AfterKeysets.new 10, [11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21]
        assert_equal 20, ac.page(2, 10)
      end

      def test_uses_block_to_transform_raw_result
        ac = AfterKeysets.new 10, [11] do |raw|
          { id: raw }
        end
        page = ac.page(1, 10)
        assert_equal(10, page)
      end
    end
  end
end
