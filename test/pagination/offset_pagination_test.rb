require_relative '../test_helper'
require_relative '../../lib/params_ready/pagination/offset_pagination'
require_relative '../../lib/params_ready/input_context'

module ParamsReady
  module Pagination
    class OffsetPaginationTest < Minitest::Test
      def get_def
        OffsetPaginationDefinition.new(0, 10).finish
      end

      def get_page
        get_def.create
      end

      def defaults_work
        page = get_page
        assert_equal(0, page.offset)
        assert_equal(10, page.limit)
      end

      def test_from_hash_works
        d = get_def
        _, page = d.from_hash({ pgn: '500-100' })
        assert_equal(500, page.offset)
        assert_equal(100, page.limit)
      end

      def test_values_clamped
        page = get_page
        page.offset = -1
        assert_equal 0, page.offset
      end

      def test_current_page_equal_to_the_original
        page = get_page
        current_page = page.update_in(page.current_page_value, [])
        assert_equal(0, current_page.offset)
        assert_equal(10, current_page.limit)
        assert_equal(1, current_page.page_no)
        assert_equal(10, current_page.num_pages(count: 100))
      end

      def test_page_shift_works
        page = get_page
        assert_nil page.previous_page_value
        next_page = page.update_in(page.next_page_value(count: 25), [])
        assert_equal(10, next_page.offset)
        assert_equal(2, next_page.page_no)
        assert_equal(10, next_page.limit)

        next_page = next_page.update_in(next_page.next_page_value(count: 25), [])
        assert_equal(20, next_page.offset)
        assert_equal(3, next_page.page_no)
        assert_equal(10, next_page.limit)
        assert_nil next_page.next_page_value(count: 25)

        first_page = next_page.first_page
        assert_equal(0, first_page.offset)
        assert_equal(1, first_page.page_no)
        assert_equal(10, first_page.limit)
        assert_nil first_page.previous_page_value

        prev_page = next_page.update_in(next_page.previous_page_value, [])
        assert_equal(10, prev_page.offset)
        assert_equal(2, prev_page.page_no)
        assert_equal(10, prev_page.limit)

        prev_page = prev_page.update_in(prev_page.previous_page_value, [])
        assert_equal(0, prev_page.offset)
        assert_equal(1, prev_page.page_no)
        assert_equal(10, prev_page.limit)
        assert_nil prev_page.previous_page_value

        assert_nil page.last_page_value(count: 0)
        assert_equal [0, 10], page.last_page_value(count: 10)
        assert_equal [10, 10], page.last_page_value(count: 11)
        last_page = page.last_page(count: 25)
        assert_equal(20, last_page.offset)
        assert_equal(3, last_page.page_no)
        assert_equal(10, last_page.limit)
      end

      def test_has_previous_returns_false_if_offset_zero
        page = get_page
        assert_equal false, page.has_previous?(1)
      end

      def test_has_previous_returns_true_if_delta_one_and_offset_less_than_limit
        page = get_page
        page.offset = 9
        assert_equal true, page.has_previous?(1)
      end

      def test_has_previous_returns_false_if_delta_greater_than_one_and_offset_less_than_limit
        page = get_page
        page.offset = 9
        assert_equal false, page.has_previous?(2)
        page.offset = 10
        assert_equal false, page.has_previous?(2)
      end

      def test_has_previous_returns_true_if_delta_times_limit_less_than_offset
        page = get_page
        page.offset = 21
        assert_equal true, page.has_previous?(2)
      end

      def test_has_previous_returns_true_if_delta_times_limit_equals_offset
        page = get_page
        page.offset = 20
        assert_equal true, page.has_previous?(2)
      end

      def test_has_previous_returns_true_if_delta_minus_one_times_limit_less_than_offset
        page = get_page
        page.offset = 19
        assert_equal true, page.has_previous?(2)
        page.offset = 11
        assert_equal true, page.has_previous?(2)
      end

      def test_has_next_returns_true_if_offset_zero_and_delta_times_limit_less_than_count
        page = get_page
        page.offset = 0
        assert_equal true, page.has_next?(1, count: 11)
      end

      def test_has_next_returns_false_if_offset_zero_and_delta_times_limit_plus_offset_equal_count
        page = get_page
        page.offset = 0
        assert_equal false, page.has_next?(1, count: 10)
      end

      def test_has_next_returns_true_if_delta_times_limit_plus_offset_less_than_count
        page = get_page
        page.offset = 9
        assert_equal true, page.has_next?(1, count: 20)
      end

      def test_has_next_returns_false_if_delta_times_limit_plus_offset_equal_count
        page = get_page
        page.offset = 9
        assert_equal false, page.has_next?(1, count: 19)
      end

      def test_previous_page_existence_checked
        page = get_page
        assert_nil page.previous_page_value
      end

      def test_no_check_whether_next_page_exists_when_count_nil
        page = get_page
        refute_nil page.next_page_value
      end

      def test_shift_page_with_non_modular_offset
        page = get_page
        page.offset = 9
        assert_equal 2, page.page_no

        prev_page = page.update_in(page.previous_page_value, [])
        assert_equal(0, prev_page.offset)
        assert_equal(1, prev_page.page_no)
        assert_equal(10, prev_page.limit)
        assert_nil prev_page.previous_page_value

        next_page = page.update_in(page.next_page_value(count: 25), [])
        assert_equal(19, next_page.offset)
        assert_equal(3, next_page.page_no)
        assert_equal(10, next_page.limit)
        assert_nil next_page.next_page_value(count: 25)

        page.offset = 10
        assert_equal 2, page.page_no
        page.offset = 11
        assert_equal 3, page.page_no
      end


      def test_num_pages_returns_zero_if_count_zero
        page = get_page
        page.limit = 10
        assert_equal 0, page.num_pages(count: 0)
      end

      def test_num_pages_returns_one_if_count_nonzero_less_than_or_equal_to_limit
        page = get_page
        page.limit = 10
        assert_equal 1, page.num_pages(count: 9)
        assert_equal 1, page.num_pages(count: 10)
      end

      def test_num_pages_returns_ceil_of_count_divided_by_limit
        page = get_page
        page.limit = 10
        assert_equal 2, page.num_pages(count: 19)
        assert_equal 2, page.num_pages(count: 20)
      end

      def test_new_offset_with_negative_delta_returns_number_if_shift_less_than_offset
        page = get_page
        page.limit = 10
        page.offset = 11
        assert_equal 1, page.new_offset(-1)
        page.offset = 21
        assert_equal 1, page.new_offset(-2)
      end

      def test_new_offset_with_negative_delta_returns_number_if_shift_less_than_offset_plus_limit
        page = get_page
        page.limit = 10
        page.offset = 1
        assert_equal 0, page.new_offset(-1)
        page.offset = 11
        assert_equal 0, page.new_offset(-2)
      end

      def test_new_offset_with_negative_delta_returns_nil_if_shift_greater_or_equal_than_offset_plus_limit
        page = get_page
        page.limit = 10
        page.offset = 0
        assert_nil page.new_offset(-1)
      end
    end
  end
end