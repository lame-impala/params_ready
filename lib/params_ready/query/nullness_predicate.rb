require_relative 'predicate'
require_relative '../parameter/value_parameter'

module ParamsReady
  module Query
    class NullnessPredicate < Parameter::AbstractParameter
      include Predicate::DelegatingPredicate
      include Predicate::HavingAttribute

      def initialize(definition)
        super definition
        @data = definition.value_parameter.create
      end

      def build_query(select_expression, context: nil)
        query = select_expression.eq(nil)
        if !unwrap
          query.not
        else
          query
        end
      end

      def perform_test(record, attribute_name)
        if unwrap
          return true if record.nil?
          record.send(attribute_name).nil?
        else
          return false if record.nil?
          !record.send(attribute_name).nil?
        end
      end

      def inspect_content
        "#{definition.attribute_name} is_null? #{@data.inspect}"
      end
    end

    class NullnessPredicateBuilder < AbstractPredicateBuilder
      include HavingAttribute
      PredicateRegistry.register_predicate :nullness_predicate, self

      include HavingValue

      def self.instance(name, altn: nil, attr: nil)
        new NullnessPredicateDefinition.new name, altn: altn, attribute_name: attr
      end
    end

    class NullnessPredicateDefinition < AbstractPredicateDefinition
      include HavingAttribute
      include Parameter::DelegatingDefinition[:value_parameter]

      attr_reader :value_parameter
      freeze_variables :value_parameter

      def initialize(*args, attribute_name: nil, **opts)
        super *args, **opts
        @attribute_name = attribute_name
        @value_parameter = Builder.builder(:boolean).instance(self.name, altn: self.altn).fetch
      end

      def finish
        @value_parameter.finish
        super
      end

      parameter_class NullnessPredicate
    end
  end
end
