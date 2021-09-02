require_relative '../test_helper'
require_relative '../../lib/params_ready/parameter/struct_parameter'

module ParamsReady
  module Parameter
    class NoInputParameterTest < Minitest::Test
      def get_no_input_param(rule:, populator: nil)
        Builder.define_struct(:parameter, altn: :param) do
          add(:symbol, :origin, altn: :orig) do
            no_input :cashdesk, rule: rule
            include &populator unless populator.nil?
          end
          add(:integer, :id) { optional }
        end
      end

      def test_no_input_parameter_with_default_uses_default
        r, p = get_no_input_param(rule: nil).from_input({ id: 5, orig: :office })
        assert r.ok?
        assert_equal :cashdesk, p[:origin].unwrap
      end

      def test_no_input_parameter_with_rule_applies_rule
        d = get_no_input_param(rule: { except: [:json] })
        r, p = d.from_input({ id: 5, orig: :office })
        assert r.ok?
        assert_equal :cashdesk, p[:origin].unwrap

        r, p = d.from_input({ id: 5, orig: :office }, context: :json)
        assert r.ok?
        assert_equal :office, p[:origin].unwrap
      end

      def test_no_input_parameter_with_populator_uses_populator
        populator = proc {
          populate do |context, param|
            param.set_value(context[:controller])
          end
        }
        d = get_no_input_param(rule: { except: [:json] }, populator: populator)
        context = InputContext.new(:frontend, { controller: :cashdesk })
        r, p = d.from_input({ id: 5, orig: :office }, context: context)
        assert r.ok?
        assert_equal :cashdesk, p[:origin].unwrap
        r, p = d.from_input({ id: 5, orig: :office }, context: :json)
        assert r.ok?
        assert_equal :office, p[:origin].unwrap
      end
    end

    class LocalParameterTest < Minitest::Test
      def get_local_param
        Builder.define_struct(:parameter, altn: :param) do
          add(:boolean, :checked, altn: :chck) do
            default false
          end
          add(:integer, :detail, altn: :dt) do
            default 0
            no_output
          end
          add(:string, :local, altn: :lc) do
            local 'local'
          end
        end
      end

      def test_local_parameter_does_not_read_from_hash_using_frontend_format
        d = get_local_param
        hash = { param: { chck: true, dt: 5, lc: 'input' }}
        _, param = d.from_hash hash
        assert_equal true, param[:checked].unwrap
        assert_equal 5, param[:detail].unwrap
        assert_equal 'local', param[:local].unwrap
      end

      def test_local_parameter_does_reads_from_hash_using_backend_format
        d = get_local_param
        hash = { parameter: { checked: true, detail: 5, local: 'input' }}
        _, param = d.from_hash hash, context: :backend
        assert_equal true, param[:checked].unwrap
        assert_equal 5, param[:detail].unwrap
        assert_equal 'input', param[:local].unwrap
      end

      def test_local_parameter_can_be_set_using_set_value
        p = get_local_param.create
        p.set_value(checked: true, detail: 5, local: 'input')

        assert_equal true, p[:checked].unwrap
        assert_equal 5, p[:detail].unwrap
        assert_equal 'input', p[:local].unwrap
      end

      def test_local_parameter_does_output_with_attributes_format
        p = get_local_param.create
        p.set_value(checked: true, detail: 5)
        output = p.for_model
        exp = {
          checked: true,
          detail: 5,
          local: 'local'
        }
        assert_equal exp, output
      end

      def test_local_parameter_does_not_output_with_frontend_format
        p = get_local_param.create
        p.set_value(checked: true, detail: 5)
        p[:local] = 'changed'
        output = p.for_frontend
        exp = {
          chck: 'true'
        }
        assert_equal exp, output
      end
    end
  end
end