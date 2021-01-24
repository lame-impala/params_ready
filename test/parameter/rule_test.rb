require_relative '../test_helper'
require_relative '../../lib/params_ready/parameter/value_parameter'
require_relative '../../lib/params_ready/result'

module ParamsReady
  module Parameter
    class RuleTest < Minitest::Test
      def assert_no_output_to_hash(p, frontend, backend)
        if frontend
          assert_equal({}, p.to_hash(:frontend))
        else
          assert_equal({int: '10'}, p.to_hash(:frontend))
        end

        if backend
          assert_equal({}, p.to_hash(:backend))
        else
          assert_equal({int: 10}, p.to_hash(:backend))
        end
      end

      def assert_no_read_from_hash(d, frontend, backend)
        if frontend
          _, p = d.from_hash({ int: 7 }, context: :frontend)
          assert_equal p.default, p.unwrap
        else
          _, p = d.from_hash({ int: 7 }, context: :frontend)
          assert_equal 7, p.unwrap
        end

        if backend
          _, p = d.from_hash({ int: 7 }, context: :backend)
          assert_equal p.default, p.unwrap
        else
          _, p = d.from_hash({ int: 7 }, context: :backend)
          assert_equal 7, p.unwrap
        end
      end

      def assert_no_output(rule, frontend, backend)
        _, p = Builder.define_integer :int do
          unless rule.nil?
            if rule == true
              no_output
            else
              no_output rule: rule
            end
          end
        end.from_input(10)

        assert_no_output_to_hash(p, frontend, backend)
      end

      def assert_local(rule, frontend, backend)
        d = Builder.define_integer :int do
          unless rule.nil?
            if rule == true
              local 5
            else
              local 5, rule: rule
            end
          else
            default 5
          end
        end

        assert_no_read_from_hash(d, frontend, backend)

        _, p = d.from_input(10)
        assert_no_output_to_hash(p, frontend, backend)
      end

      def assert_skip_processing(method, rule, frontend, backend)
        d = Builder.define_integer :int do
          if method == :preprocess
            preprocess(rule: rule) do |value, _|
              value + 1
            end
          elsif method == :postprocess
            postprocess(rule: rule) do |param, _|
              param.set_value(param.unwrap + 1)
            end
          end
        end

        if frontend
          _, p = d.from_hash({ int: 5 }, context: :frontend)
          assert_equal 5, p.unwrap
        else
          _, p = d.from_hash({ int: 5 }, context: :frontend)
          assert_equal 6, p.unwrap
        end

        if backend
          _, p = d.from_hash({ int: 5 }, context: :backend)
          assert_equal 5, p.unwrap
        else
          _, p = d.from_hash({ int: 5 }, context: :backend)
          assert_equal 6, p.unwrap
        end
      end

      def test_no_output_works
        assert_no_output nil, false, false
        assert_no_output true, true, false
        assert_no_output :all, true, true
        assert_no_output :none, false, false
        assert_no_output({ only: [:frontend] }, true, false)
        assert_no_output({ only: [:backend] }, false, true)
      end

      def test_local_works
        assert_local nil, false, false
        assert_local true, true, false
        assert_local :all, true, true
        assert_local :none, false, false
        assert_local({ only: [:frontend] }, true, false)
        assert_local({ only: [:backend] }, false, true)
      end

      def test_skip_preprocess_works
        assert_skip_processing :preprocess, nil, false, true
        assert_skip_processing :preprocess, :all, false, false
        assert_skip_processing :preprocess, :none, true, true
        assert_skip_processing :preprocess, { only: [:frontend] }, false, true
        assert_skip_processing :preprocess, { only: [:backend] }, true, false
      end

      def test_skip_postprocess_works
        assert_skip_processing :postprocess, nil, false, true
        assert_skip_processing :postprocess, :all, false, false
        assert_skip_processing :postprocess, :none, true, true
        assert_skip_processing :postprocess, { only: [:frontend] }, false, true
        assert_skip_processing :postprocess, { only: [:backend] }, true, false
      end
    end
  end
end