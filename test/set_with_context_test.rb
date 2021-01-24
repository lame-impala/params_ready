require_relative 'test_helper'

module ParamsReady
  class SetWithInputContextTest < Minitest::Test
    def long_names
      {
        parameter: {
          detail: 'Good sport',
          roles: [0, 2, 4],
          actions: {
            view: true,
            edit: true
          },
          score: '6|3',
          evaluation: {
            rating: 9
          }
        }
      }
    end

    def alternative_keys
      {
        parameter: {
          d: 'Good sport',
          rr: [0, 2, 4],
          aa: {
            v: true,
            e: true
          },
          s: '6|3',
          e: {
            r: 9
          }
        }
      }
    end

    def assert_is_set(p)
      assert p[:detail].is_definite?
      assert p[:roles].is_definite?
      assert_equal 3, p[:roles].length
      assert p[:actions].is_definite?
      assert p[:actions][:view].is_definite?
      assert p[:actions][:edit].is_definite?
      assert p[:score].is_definite?
      assert_equal 6, p[:score].first.unwrap
      assert_equal 3, p[:score].second.unwrap
      assert p[:evaluation].is_definite?
      assert_equal({ rating: 9 }, p[:evaluation].unwrap)
    end

    def refute_is_set(p)
      refute p[:detail].is_definite?
      refute p[:roles].is_definite?
      refute p[:actions].is_definite?
      refute p[:score].is_definite?
      refute p[:evaluation].is_definite?
    end

    def test_long_keys_are_not_found_when_context_nil
      d = get_complex_param_definition
      _, p = d.from_hash(long_names)
      refute_is_set(p)
    end

    def test_alternative_keys_are_found_when_context_nil
      d = get_complex_param_definition
      _, p = d.from_hash(alternative_keys)
      assert_is_set(p)
    end

    def test_long_keys_are_found_when_context_backend
      d = get_complex_param_definition
      _, p = d.from_hash(long_names, context: Format.instance(:backend))
      assert_is_set(p)
    end

    def test_alternative_keys_not_found_when_context_backend
      d = get_complex_param_definition
      _, p = d.from_hash(alternative_keys, context: Format.instance(:backend))
      refute_is_set(p)
    end

    def test_long_keys_not_found_when_context_frontent
      d = get_complex_param_definition
      _, p = d.from_hash(long_names, context: Format.instance(:frontend))
      refute_is_set(p)
    end

    def test_alternative_keys_found_when_context_frontend
      d = get_complex_param_definition
      _, p = d.from_hash(alternative_keys, context: Format.instance(:frontend))
      assert_is_set(p)
    end
  end
end
