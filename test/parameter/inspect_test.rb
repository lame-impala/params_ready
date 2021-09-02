require_relative '../test_helper'
require_relative '../../lib/params_ready'

module ParamsReady
  module Parameter
    class InspectTest < Minitest::Test
      def get_def
        Builder.define_struct :inspect do
          add :integer, :integer
          add :string, :string
          add :symbol, :symbol
          add :date, :date
          add :tuple, :tuple do
            field :integer, :first
            field :symbol, :second
            marshal using: :string, separator: '-'
          end
          add :array, :array do
            prototype :string
          end
        end
      end

      def get_secretive_def
        Builder.define_struct :inspect do
          add :integer, :integer do
            local 10
          end
          add :string, :string do
            no_output
          end
          add :symbol, :symbol do
            no_output rule: { except: [:inspect] }
          end
          add :date, :date do
            no_output
          end
          add :tuple, :tuple do
            field :integer, :first
            field :symbol, :second
            local [12, 'ct']
            marshal using: :string, separator: '-'
          end
          add :array, :array do
            no_output
            prototype :string
          end
        end
      end

      def get_param(d)
        inp = {
          integer: 10,
          string: 'foo',
          symbol: :sym,
          date: '2021-05-05',
          tuple: '12-ct',
          array: { cnt: 2, '0': 'bar', '1': 'bax' }
        }
        r, p = d.from_input(inp)
        assert r.ok?, r.errors.map(&:message).join(', ')
        p
      end

      def test_inspect_works
        d = get_def
        p = get_param(d)

        exp = <<~INSP
          StructParameter inspect: { 
           {:integer=>ValueParameter integer: { 10 }, 
            :string=>ValueParameter string: { \"foo\" }, 
            :symbol=>ValueParameter symbol: { :sym }, 
            :date=>ValueParameter date: { Wed, 05 May 2021 }, 
            :tuple=>TupleParameter tuple: { [ValueParameter first: { 12 }, ValueParameter second: { :ct }] }, 
            :array=>ArrayParameter array: { [ValueParameter element: { \"bar\" }, ValueParameter element: { \"bax\" }] }} }
        INSP
        assert_equal exp.unformat, p.inspect
      end

      def test_inspect_does_not_show_secrets
        d = get_secretive_def
        p = get_param(d)

        exp = <<~INSP
          StructParameter inspect: { 
           {:integer=>ValueParameter integer: { [FILTERED] }, 
            :string=>ValueParameter string: { [FILTERED] }, 
            :symbol=>ValueParameter symbol: { :sym }, 
            :date=>ValueParameter date: { [FILTERED] }, 
            :tuple=>TupleParameter tuple: { [FILTERED] }, 
            :array=>ArrayParameter array: { [FILTERED] }} }
        INSP
        assert_equal exp.unformat, p.inspect
      end
    end
  end
end