require 'date'
require_relative '../../lib/params_ready/value/validator.rb'
require_relative '../test_helper'

module ParamsReady
  module Value
    class ConstraintTest < MiniTest::Test
      def test_range_constraint_works_with_numbers
        c = Constraint.instance(1..3)
        assert(c.valid?(1))
        assert(c.valid?(2))
        assert(c.valid?(3))
        refute(c.valid?(0))
        refute(c.valid?(4))
        assert c.clamp?
        assert_equal 1, c.clamp(0)
        assert_equal 2, c.clamp(2)
        assert_equal 3, c.clamp(4)
      end

      def test_indefinite_values_not_subject_to_constraints
        c = Constraint.instance(1..3)
        v = Validator.instance(c)
        assert_equal([Extensions::Undefined, nil], v.validate(Extensions::Undefined, nil))
        assert_equal([nil, nil], v.validate(nil, nil))
      end

      def test_undefine_strategy_returns_undefined
        c = Validator.instance(Constraint.instance(1..3), strategy: :undefine)
        assert_equal([Extensions::Undefined, nil], c.validate(5, nil))
      end

      def test_range_constraint_works_with_date
        today = Date.today
        past = today - 10
        yesterday = today - 1
        tomorrow = today + 1
        future = today + 10
        c = Constraint.instance(yesterday..tomorrow)
        assert(c.valid?(yesterday))
        assert(c.valid?(today))
        assert(c.valid?(tomorrow))
        refute(c.valid?(past))
        refute(c.valid?(future))
      end

      def test_enum_constraint_works_with_numbers
        c = Constraint.instance([1, 3])
        assert(c.valid?(1))
        assert(c.valid?(3))
        refute(c.valid?(2))
        refute(c.valid?(0))
        refute(c.valid?(4))
      end

      def test_enum_constraint_works_with_dates
        today = Date.today
        past = today - 10
        yesterday = today - 1
        tomorrow = today + 1
        future = today + 10
        c = Constraint.instance([yesterday, tomorrow])
        assert(c.valid?(yesterday))
        assert(c.valid?(tomorrow))
        refute(c.valid?(today))
        refute(c.valid?(past))
        refute(c.valid?(future))
      end

      def test_enum_constraint_works_with_strings
        c = Constraint.instance(%w[yesterday tomorrow])
        assert(c.valid?('yesterday'))
        assert(c.valid?('tomorrow'))
        refute(c.valid?('today'))
      end

      def test_enum_constraint_works_with_symbols
        c = Constraint.instance([:yesterday, :tomorrow])
        assert(c.valid?(:yesterday))
        assert(c.valid?(:tomorrow))
        refute(c.valid?(:today))
      end

      def test_symbol_enum_constraint_works_with_strings
        c = Constraint.instance([:yesterday, :tomorrow])
        assert(c.valid?('yesterday'))
        assert(c.valid?('tomorrow'))
        refute(c.valid?('today'))
      end

      def test_operator_constraint_raises_with_invalid_operator
        ex = assert_raises do
          OperatorConstraint.new(:x, 1)
        end
        assert '', ex.message
      end

      def test_operator_that_do_not_clamp_raise_if_strategy_clamp
        %i(< > =~).each do |op|
          err = assert_raises(ParamsReadyError) do
            Validator.instance(:operator, op, 5, strategy: :clamp)
          end
          assert_equal "Clamping not applicable", err.message
        end
      end

      def test_operator_constraint_works
        c = OperatorConstraint.new(:<, 1)
        assert c.valid?(0)
        refute c.valid?(1)
        refute c.clamp?
        c = OperatorConstraint.new(:<=, 1)
        assert c.valid?(1)
        refute c.valid?(2)
        assert c.clamp?
        assert_equal 0, c.clamp(0)
        assert_equal 1, c.clamp(100)
        c = OperatorConstraint.new(:==, 1)
        assert c.valid?(1)
        refute c.valid?(2)
        assert c.clamp?
        assert_equal 1, c.clamp(1)
        assert_equal 1, c.clamp(-100)
        c = OperatorConstraint.new(:>=, 1)
        refute c.valid?(0)
        assert c.valid?(1)
        assert c.clamp?
        assert_equal 100, c.clamp(100)
        assert_equal 1, c.clamp(-100)
        c = OperatorConstraint.new(:>, 1)
        assert c.valid?(2)
        refute c.valid?(1)
        refute c.clamp?
      end

      def test_operator_constraint_builder_works_with_proc
        c = OperatorConstraint.build(:<) do
          1
        end
        assert c.valid?(0)
        refute c.valid?(1)
      end

      def test_operator_constraint_works_with_proc
        one = Proc.new do
          1
        end
        c = OperatorConstraint.new(:<, one)
        assert c.valid?(0)
        refute c.valid?(1)
        refute c.clamp?
        c = OperatorConstraint.new(:<=, one)
        assert c.valid?(1)
        refute c.valid?(2)
        assert c.clamp?
        assert_equal 1, c.clamp(5)
        c = OperatorConstraint.new(:==, one)
        assert c.valid?(1)
        refute c.valid?(2)
        assert c.clamp?
        assert_equal 1, c.clamp(5)
        c = OperatorConstraint.new(:>=, one)
        assert c.valid?(1)
        refute c.valid?(0)
        assert c.clamp?
        assert_equal 1, c.clamp(0)
        c = OperatorConstraint.new(:>, one)
        assert c.valid?(2)
        refute c.valid?(1)
        refute c.clamp?
      end

      def test_operator_constraint_works_with_method
        c = OperatorConstraint.new(:<, method(:one))
        assert c.valid?(0)
        refute c.valid?(1)
        refute c.clamp?
        c = OperatorConstraint.new(:<=, method(:one))
        assert c.valid?(1)
        refute c.valid?(2)
        assert c.clamp?
        assert_equal 1, c.clamp(5)
        c = OperatorConstraint.new(:==, method(:one))
        assert c.valid?(1)
        refute c.valid?(2)
        assert c.clamp?
        assert_equal 1, c.clamp(5)
        c = OperatorConstraint.new(:>=, method(:one))
        assert c.valid?(1)
        refute c.valid?(0)
        assert c.clamp?
        assert_equal 1, c.clamp(0)
        c = OperatorConstraint.new(:>, method(:one))
        assert c.valid?(2)
        refute c.valid?(1)
        refute c.clamp?
      end

      def test_operator_constraint_works_with_regex
        c = OperatorConstraint.new(:=~, /a/)
        assert c.valid?("cat")
        refute c.valid?("cod")
      end

      def one
        1
      end
    end
  end
end