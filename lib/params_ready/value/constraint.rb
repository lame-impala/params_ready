require 'set'
require_relative '../extensions/undefined'
require_relative '../extensions/registry'
require_relative '../error'

module ParamsReady
  module Value

    class Constraint
      class Error < ParamsReadyError; end

      extend Extensions::Registry
      registry :constraint_types, as: :constraint_type, getter: true

      def self.register(name)
        Constraint.register_constraint_type(name, self)
      end

      attr_reader :condition

      def initialize(cond)
        @condition = cond.freeze
        freeze
      end

      def clamp?; false; end

      def self.build(cond, *args, **opts, &block)
        if block.nil?
          new cond, *args, **opts
        else
          new cond, block, *args, **opts
        end
      end

      def self.instance(cond, *args, **opts)
        case cond
        when Range
          RangeConstraint.new(cond, *args, **opts)
        when Array, Set
          EnumConstraint.new(cond, *args, **opts)
        else
          raise ParamsReadyError, "Unknown constraint type: " + cond.class.name
        end
      end

      def valid?(input)
        raise ParamsReadyError, 'This is an abstract class'
      end

      def error_message
        "didn't pass validation"
      end
    end

    class RangeConstraint < Constraint
      register :range

      def initialize(cond, *args, **opts)
        raise ParamsReadyError, "Expected Range, got: " + cond.class.name unless cond.is_a?(Range)
        super cond, *args, **opts
      end

      def valid?(input)
        @condition.include?(input)
      end

      def error_message
        'not in range'
      end

      def clamp(value)
        if value < @condition.min
          @condition.min
        elsif value > @condition.max
          @condition.max
        else
          value
        end
      end

      def clamp?
        return false if @condition.min.nil? || @condition.max.nil?

        true
      end
    end

    class EnumConstraint < Constraint
      register :enum

      def initialize(cond, *args, **opts)
        raise ParamsReadyError, "Expected Set or Array, got: " + cond.class.name unless
          cond.is_a?(Set) ||
          cond.is_a?(Array)
        super cond, *args, **opts
      end

      def valid?(input)
        if input.is_a?(String)
          @condition.include?(input) || @condition.include?(input.to_sym)
        else
          @condition.include?(input)
        end
      end

      def error_message
        'not in enum'
      end
    end

    class OperatorConstraint < Constraint
      register :operator

      OPERATORS = [:=~, :<, :<=, :==, :>=, :>].to_set.freeze

      def initialize(operator, value, *args, **opts)
        unless OPERATORS.member? operator
          raise ParamsReadyError, "Unsupported operator: #{operator}"
        end
        cond = Condition.instance(operator, value)
        super(cond, *args, **opts)
      end

      def clamp(value)
        return value if valid?(value)

        @condition.clamp(value)
      end

      def clamp?
        @condition.clamp?
      end

      def valid?(input)
        @condition.true?(input)
      end

      def error_message
        @condition.error_message
      end

      module ClampingCondition
        CLAMPING_OPERATORS = %i(<= == >=).to_set.freeze
        def clamp(_)
          case @operator
          when :<=, :>=, :==
            get_value
          else
            raise "Unexpected operator: #{@operator}"
          end
        end

        def clamp?
          CLAMPING_OPERATORS.member? @operator
        end
      end

      class Condition
        include ClampingCondition

        def initialize(operator, value)
          @operator = operator
          @value = value
        end

        def true?(input)
          input.send(@operator, get_value)
        end

        def error_message
          "not #{@operator} #{get_value}"
        end

        def self.instance(operator, value)
          case value
          when Method, Proc
             DynamicCondition.new operator, value
          else
             StaticCondition.new operator, value
          end
        end
      end

      class StaticCondition < Condition
        def get_value
          @value
        end
      end

      class DynamicCondition < Condition
        def get_value
          @value.call
        end
      end
    end
  end
end