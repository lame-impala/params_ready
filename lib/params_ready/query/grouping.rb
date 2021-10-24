require_relative 'join_clause'
require_relative '../parameter/parameter'
require_relative '../parameter/value_parameter'

module ParamsReady
  class Builder
    module GroupingLike
      def predicate_builder(name)
        symbol = name.to_sym
        return nil unless Query::PredicateRegistry.has_predicate?(symbol)

        Query::PredicateRegistry.predicate(symbol)
      end

      def method_missing(name, *args, **opts, &proc)
        builder_class = predicate_builder(name)
        if builder_class
          builder = builder_class.instance *args, **opts
          build_predicate builder, &proc
        else
          super
        end
      end

      def respond_to_missing?(name, include_private = false)
        return true unless predicate_builder(name).nil?

        super
      end

      def build_predicate(builder, &proc)
        builder.instance_eval(&proc)
        definition = builder.build
        add_predicate definition
      end

      def add_predicate(name_or_definition, *args, **opts, &block)
        if name_or_definition.is_a? Parameter::AbstractDefinition
          @definition.add_predicate name_or_definition
          add name_or_definition
        else
          builder = predicate_builder(name_or_definition).instance *args, **opts
          build_predicate builder, &block
        end
      end

      def operator(&block)
        definition = Builder.define_grouping_operator(:operator, altn: :op, &block)
        add definition
      end

      def to_query?(&block)
        helper :to_query?, &block
      end
    end
  end

  module Parameter
    module GroupingLike
      def predicate_group(arel_table, context: Restriction.blanket_permission)
        subqueries = predicates.reduce(nil) do |acc, predicate|
          query = predicate.to_query_if_eligible(arel_table, context: context)
          # This duplicates the operator logic
          # but we want operator to be optional
          # for single predicate groupings
          next query if acc.nil?

          operator.connect(acc, query)
        end
        return nil if subqueries.nil?
        arel_table.grouping(subqueries)
      end

      def eligible_for_query?(table, context)
        return false unless context.permitted? self
        return false unless is_definite?
        return true unless respond_to?(:to_query?)

        to_query?(table, context)
      end

      def to_query_if_eligible(arel_table, context:)
        return nil unless eligible_for_query?(arel_table, context)

        context = context_for_predicates(context)
        to_query(arel_table, context: context)
      end

      def to_query(arel_table, context: Restriction.blanket_permission)
        self.predicate_group(arel_table, context: context)
      end

      def test(record)
        return nil unless is_definite?

        predicates = self.predicates
        return nil if predicates.empty?

        operator.test(record, predicates)
      end
    end
  end

  module Query
    class GroupingOperatorCoder < Value::SymbolCoder
      def self.coerce(value, _)
        return value if value.is_a? GroupingOperator

        symbol = super
        GroupingOperator.instance(symbol)
      end

      def self.format(value, _)
        value.type.to_s
      end

      def self.strict_default?
        false
      end
    end

    Parameter::ValueParameterBuilder.register_coder :grouping_operator, GroupingOperatorCoder

    class GroupingOperator
      attr_reader :type

      def self.instance(type)
        raise ParamsReadyError, "Unimplemented operator: #{type}" unless @instances.key? type
        @instances[type]
      end

      def arel_method
        case type
        when :and, :or then type
        else
          raise ParamsReadyError, "Unimplemented operator: #{type}"
        end
      end

      def test_method
        case type
        when :and then :all?
        when :or then :any?
        else
          raise ParamsReadyError, "Unimplemented operator: #{type}"
        end
      end

      def connect(a, b)
        return b if a.nil?
        return a if b.nil?
        a.send arel_method, b
      end

      def ==(other)
        return false unless other.class <= GroupingOperator
        type == other.type
      end

      def test(record, predicates)
        definite = predicates.map do |predicate|
          predicate.test(record)
        end.compact

        return nil if definite.empty?

        definite.send(test_method)
      end

      protected

      def initialize(type)
        @type = type
      end

      @instances = {}
      @instances[:and] = GroupingOperator.new(:and)
      @instances[:or] = GroupingOperator.new(:or)

      private_class_method :new
    end
  end
end
