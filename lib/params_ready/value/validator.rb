require_relative 'constraint'

module ParamsReady
  module Value
    class Validator
      attr_reader :constraint, :strategy

      def self.instance(name_or_constraint, *args, strategy: :raise, **opts, &block)
        constraint = case name_or_constraint
        when Value::Constraint
          name_or_constraint
        when Symbol
          type = Value::Constraint.constraint_type(name_or_constraint)
          type.build(*args, **opts, &block)
        else
          valid, missing_method = valid_constraint?(name_or_constraint, strategy)
          on_constraint_invalid(missing_method) unless valid
          name_or_constraint
        end
        new(constraint, strategy: strategy)
      end

      def self.on_constraint_invalid(missing_method)
        raise ParamsReadyError, "Not a valid constraint, '#{missing_method}' unimplemented"
      end

      def self.valid_constraint?(constraint, strategy)
        return [false, 'valid?'] unless constraint.respond_to?(:valid?)
        return [false, 'error_message'] unless constraint.respond_to?(:error_message)
        return [true, nil] unless strategy == :clamp
        return [false, 'clamp'] unless constraint.respond_to? :clamp

        [true, nil]
      end

      def initialize(constraint, strategy: :raise)
        @constraint = constraint
        @strategy = check_strategy(constraint, strategy)
        freeze
      end

      def check_strategy(constraint, strategy)
        case strategy.to_sym
        when :raise, :undefine
          strategy.to_sym
        when :clamp
          if constraint.respond_to? :clamp?
            raise ParamsReadyError, 'Clamping not applicable' unless constraint.clamp?
          end
          strategy.to_sym
        else
          raise ParamsReadyError, "Unexpected constraint strategy #{strategy}"
        end
      end

      def validate(value, result)
        return [value, result] if Extensions::Undefined.value_indefinite?(value)

        if constraint.valid? value
          [value, result]
        else
          case strategy
          when :raise
            e = Constraint::Error.new("value '#{value}' #{constraint.error_message}")
            if result.nil?
              raise e
            else
              result.error! e
            end
            [Extensions::Undefined, result]
          when :clamp
            [constraint.clamp(value), result]
          else
            [Extensions::Undefined, result]
          end
        end
      end

    end
  end
end