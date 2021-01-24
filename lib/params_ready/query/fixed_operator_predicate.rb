require 'forwardable'

require_relative '../parameter/value_parameter'
require_relative '../parameter/array_parameter'
require_relative 'predicate'
require_relative 'predicate_operator'

module ParamsReady
  module Query
    class FixedOperatorPredicate < Parameter::AbstractParameter
      include Predicate::DelegatingPredicate
      include Predicate::HavingAttribute

      def initialize(definition, **options)
        super definition
        @data = definition.type.create
      end

      def build_query(select_expression, context: nil)
        definition.operator.to_query(select_expression, @data.unwrap)
      end

      def perform_test(record, attribute_name)
        definition.operator.test(record, attribute_name, @data.unwrap)
      end

      def inspect_content
        op = definition.operator.name
        "#{definition.attribute_name} #{op} #{@data.inspect}"
      end
    end

    class FixedOperatorPredicateBuilder < AbstractPredicateBuilder
      PredicateRegistry.register_predicate :fixed_operator_predicate, self
      include HavingType
      include HavingValue
      include HavingAttribute

      def self.instance(name, altn: nil, attr: nil)
        new FixedOperatorPredicateDefinition.new name, altn: altn, attribute_name: attr
      end

      def data_object_handles
        [@definition.name, @definition.altn]
      end

      def operator(name)
        operator = PredicateRegistry.operator name, Format.instance(:backend)
        @definition.set_operator operator
      end
    end

    class FixedOperatorPredicateDefinition < AbstractPredicateDefinition
      extend Forwardable
      include HavingAttribute
      include Parameter::DelegatingDefinition[:type]

      late_init :operator, obligatory: true
      late_init :type, obligatory: true, freeze: false

      def initialize(*args, attribute_name: nil, type: nil, operator: nil, **opts)
        @attribute_name = attribute_name
        @type = type
        @operator = operator
        @associations = []
        super *args, **opts
      end

      def finish
        @type.finish
        super
      end

      parameter_class FixedOperatorPredicate
    end
  end
end
