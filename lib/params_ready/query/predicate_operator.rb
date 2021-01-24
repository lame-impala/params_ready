require_relative 'predicate'

module ParamsReady
  module Query
    class PredicateOperator
      def self.dup
        self
      end

      def self.define_operator(name, altn, arel: nil, test: nil, inverse_of: nil)
        define_singleton_method :name do
          name
        end

        define_singleton_method :altn do
          altn
        end

        if arel
          define_singleton_method :to_query do |attribute, value|
            attribute.send(arel, value)
          end
        end

        if test
          define_singleton_method :test do |record, attribute_name, value|
            attribute = record.send attribute_name
            attribute.send test, value
          end
        end

        define_singleton_method :inverse_of do
          inverse_of
        end

        unless PredicateRegistry.operator(self.name, Format.instance(:backend), true).nil?
          raise ParamsReadyError, "Operator name taken #{self.name}"
        end

        unless PredicateRegistry.operator(self.altn, Format.instance(:frontend), true).nil?
          raise ParamsReadyError, "Operator altn taken #{self.name}"
        end

        PredicateRegistry.register_operator_by_name self
        PredicateRegistry.register_operator_by_alt_name self
      end

      def altn
        self.class.altn
      end
    end

    class In < PredicateOperator
      define_operator :in, :in, arel: :in

      def self.test(record, attribute_name, values)
        attribute = record.send attribute_name
        values.include? attribute
      end
    end


    class ComparisonPredicateOperator < PredicateOperator; end

    class Like < ComparisonPredicateOperator
      define_operator :like, :lk

      def self.to_query(attribute_name, value)
        attribute_name.matches("%#{value}%")
      end

      def self.test(record, attribute_name, value)
        attribute = record.send attribute_name
        result = Regexp.new(value, Regexp::IGNORECASE) =~ attribute
        result.nil? ? false : true
      end
    end

    class Equal < ComparisonPredicateOperator
      define_operator :equal, :eq, arel: :eq, test: :==
    end

    class NotEqual < ComparisonPredicateOperator
      define_operator :not_equal, :neq, arel: :not_eq, test: :!=
    end

    class GreaterThan < ComparisonPredicateOperator
      define_operator :greater_than, :gt, arel: :gt, test: :>, inverse_of: :less_than_or_equal

      def self.test(record, attribute_name, value)
        attribute = record.send attribute_name
        attribute > value
      end
    end

    class LessThan < ComparisonPredicateOperator
      define_operator :less_than, :lt, arel: :lt, test: :<, inverse_of: :greater_than_or_equal
    end

    class GraterThanOrEqual < ComparisonPredicateOperator
      define_operator :greater_than_or_equal, :gteq, arel: :gteq, test: :>=, inverse_of: :less_than
    end

    class LessThanOrEqual < ComparisonPredicateOperator
      define_operator :less_than_or_equal, :lteq, arel: :lteq, test: :<=, inverse_of: :greater_than
    end

    class Not
      def initialize(operator)
        @operator = operator
      end

      def name
        "not_#{@operator.name}"
      end

      def altn
        "n#{@operator.altn}"
      end

      def test(*args)
        result = @operator.test *args
        !result
      end

      def to_query(*args)
        result = @operator.to_query(*args)
        result.not
      end
    end
  end
end