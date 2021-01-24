require_relative '../test_helper'
require_relative '../../lib/params_ready/parameter/hash_parameter'

module ParamsReady
  module Parameter
    class MemoTest < Minitest::Test
      def test_cached_value_is_deep_frozen
        m = Helpers::Memo.new
        int = Intent.instance(:frontend)
        h = { a: { b: { c: 'foo' }}}
        m.cache_value(h, int)
        assert h[:a][:b].frozen?
        assert h[:a][:b][:c].frozen?
      end

      def test_memo_with_three_slots_stores_first_value
        m = Helpers::Memo.new 3
        int = Intent.instance(:frontend).permit(:users)
        m.cache_value('foo', int)
        h = m.instance_variable_get(:@cache)
        assert_equal 1, h.length
        assert h.frozen?
        assert_equal([[int, 'foo']], h.to_a)
      end

      def test_memo_with_three_slots_keeps_first_value_if_repeated
        m = Helpers::Memo.new 3
        int = Intent.instance(:frontend).permit(:users)
        m.cache_value('foo', int)
        m.cache_value('foo', int)
        h = m.instance_variable_get(:@cache)
        assert_equal 1, h.length
        assert h.frozen?
        assert_equal([[int, 'foo']], h.to_a)
      end

      def test_memo_with_three_slots_stores_second_value
        m = Helpers::Memo.new 3
        int1 = Intent.instance(:frontend).permit(:users)
        int2 = Intent.instance(:frontend).permit(:posts)
        m.cache_value('foo', int1)
        m.cache_value('bar', int2)
        h = m.instance_variable_get(:@cache)
        assert_equal 2, h.length
        assert h.frozen?
        assert_equal([[int1, 'foo'], [int2, 'bar']], h.to_a)
      end

      def test_memo_with_three_slots_stores_third_value
        m = Helpers::Memo.new 3
        int1 = Intent.instance(:frontend).permit(:users)
        int2 = Intent.instance(:frontend).permit(:posts)
        int3 = Intent.instance(:backend).permit(:posts)
        m.cache_value('foo', int1)
        m.cache_value('bar', int2)
        m.cache_value('baz', int3)
        h = m.instance_variable_get(:@cache)
        assert_equal 3, h.length
        assert h.frozen?
        assert_equal([[int1, 'foo'], [int2, 'bar'], [int3, 'baz']], h.to_a)
      end

      def test_memo_with_three_slots_stores_fourth_value_keeping_last_three
        m = Helpers::Memo.new 3
        int1 = Intent.instance(:frontend).permit(:users)
        int2 = Intent.instance(:frontend).permit(:posts)
        int3 = Intent.instance(:backend).permit(:posts)
        int4 = Intent.instance(:backend).permit(:users, :posts)
        m.cache_value('foo', int1)
        m.cache_value('bar', int2)
        m.cache_value('baz', int3)
        m.cache_value('bax', int4)
        h = m.instance_variable_get(:@cache)
        assert_equal 3, h.length
        assert h.frozen?
        assert_equal([[int2, 'bar'], [int3, 'baz'], [int4, 'bax']], h.to_a)
      end

      def test_memo_containing_two_values_will_not_add_repeated_value
        m = Helpers::Memo.new 3
        int1 = Intent.instance(:frontend).permit(:users)
        int2 = Intent.instance(:frontend).permit(:posts)
        m.cache_value('foo', int1)
        m.cache_value('bar', int2)
        m.cache_value('foo', int1)
        h = m.instance_variable_get(:@cache)
        assert_equal 2, h.length
        assert h.frozen?
        assert_equal([[int1, 'foo'], [int2, 'bar']], h.to_a)
      end
    end

    class MemoParamTest < Minitest::Test
      def get_def(memo:)
        Builder.define_hash :memo do
          add :string, :str
          add :integer, :int
          memoize if memo
        end
      end

      def get_param(memo:)
        d = get_def memo: memo
        _, p = d.from_input({ str: 'foo', int: 5 })
        p
      end

      def get_intent
        f = Format.new(marshal: { only: [:value, :number] }, omit: [:undefined], naming_scheme: :alternative, remap: true, local: false, name: :old)
        r = Restriction.permit(:str, :int)
        [f, r]
      end

      def retrieve_cached_output(p)
        memo = p.instance_variable_get(:@memo)
        cache = memo.instance_variable_get(:@cache)
        return [Extensions::Undefined, nil] if cache.nil?

        int, val = cache.first
        [val, int]
      end

      def test_no_memo_when_memoize_unset
        p = get_param(memo: false)
        assert_nil p.instance_variable_get(:@memo)
      end

      def test_no_memo_in_unfrozen_param_when_memoize_set
        p = get_param(memo: true)
        assert_nil p.instance_variable_get(:@memo)
      end

      def test_memo_created_on_freeze_when_memoize_set
        p = get_param(memo: true)
        p.freeze
        val, int = retrieve_cached_output(p)
        assert_equal(Extensions::Undefined, val)
        assert_nil int
      end

      def test_unfrozen_param_does_not_memoize
        p = get_param(memo: true)
        _r = p.for_frontend
        assert_nil p.instance_variable_get(:@memo)
      end

      def test_memo_populated_on_output_in_frozen_param
        p = get_param(memo: true)
        p.freeze
        r = p.for_frontend
        val, int = retrieve_cached_output(p)
        assert_equal(r, val)
        assert_equal Intent.instance(:frontend), int
      end

      def test_memo_used_on_output_for_identical_intent
        p = get_param(memo: true)
        p.freeze
        r1 = p.for_frontend
        r2 = p.for_frontend
        val, int = retrieve_cached_output(p)

        assert_equal r1.object_id, val.object_id
        assert_equal r1.object_id, r2.object_id
        assert_equal Intent.instance(:frontend), int
      end

      def test_memo_updated_for_different_intent
        p = get_param(memo: true)
        p.freeze

        r1 = p.for_frontend
        val, int = retrieve_cached_output(p)
        assert_equal r1.object_id, val.object_id
        assert_equal Intent.instance(:frontend), int

        r2 = p.for_model
        val, int = retrieve_cached_output(p)
        assert_equal r2.object_id, val.object_id
        assert_equal Intent.instance(:attributes), int

        f, r = get_intent
        r3 = p.for_output(f, restriction: r)
        val, int = retrieve_cached_output(p)
        assert_equal r3.object_id, val.object_id
        assert_equal Intent.new(f, r), int
      end

      def test_memo_discarded_in_updated_param
        p1 = get_param(memo: true)
        p1.freeze
        r = p1.for_frontend
        p2 = p1.update_in('bar', [:str])
        val, int = retrieve_cached_output(p1)
        assert_equal r, val
        assert_equal Intent.instance(:frontend), int
        val, int = retrieve_cached_output(p2)
        assert_equal Extensions::Undefined, val
        assert_nil int
      end

      def test_memo_kept_if_update_ineffective
        p1 = get_param(memo: true)
        p1.freeze
        _ = p1.for_frontend
        p2 = p1.update_in('foo', [:str])
        val1, int1 = retrieve_cached_output(p1)
        val2, int2 = retrieve_cached_output(p2)

        assert_equal(val1, val2)
        assert_equal(int1, int2)
      end

      def get_complex_def
        memo = get_def(memo: true)
        Builder.define_hash :wrapper do
          add memo
          add :string, :name
        end
      end

      def get_complex_param
        d = get_complex_def
        _, p = d.from_input({ memo: { str: 'foo', int: 5 }, name: 'FOO' })
        p
      end

      def test_memo_discarded_if_nested_param_updated
        p1 = get_complex_param
        p1.freeze
        _ = p1.for_frontend
        p2 = p1.update_in('bar', [:memo, :str])
        val1, int2 = retrieve_cached_output(p1[:memo])
        assert_equal({ str: 'foo', int: '5' }, val1)
        refute_nil int2
        val2, int2 = retrieve_cached_output(p2[:memo])
        assert_equal Extensions::Undefined, val2
        assert_nil int2
      end

      def test_memo_kept_if_nested_param_shared
        p1 = get_complex_param
        p1.freeze
        _ = p1.for_frontend
        p2 = p1.update_in('BAR', [:name])
        val1, int1 = retrieve_cached_output(p1[:memo])
        assert_equal({ str: 'foo', int: '5' }, val1)
        refute_nil int1
        val2, int2 = retrieve_cached_output(p2[:memo])
        assert_equal(val1, val2)
        assert_equal(int1, int2)
      end
    end
  end
end