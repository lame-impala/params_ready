require_relative '../parameter/hash_parameter'
require_relative '../parameter/value_parameter'
require_relative 'fixed_operator_predicate'
require_relative 'nullness_predicate'
require_relative 'grouping'

module ParamsReady
  module Query
    class StructuredGrouping < Parameter::HashParameter
      include Parameter::GroupingLike
      def predicates
        return [] if is_nil?

        definition.predicates.keys.map do |name|
          parameter = child(name)
          next nil unless parameter.is_definite?
          parameter
        end.compact
      end

      def operator
        self[:operator].unwrap
      end

      def context_for_predicates(restriction)
        intent_for_children(restriction)
      end
    end

    class StructuredGroupingBuilder < Builder
      include GroupingLike
      include Parameter::AbstractHashParameterBuilder::HashLike
      PredicateRegistry.register_predicate :structured_grouping_predicate, self

      def self.instance(name, altn: nil)
        new StructuredGroupingDefinition.new(name, altn: altn)
      end
    end

    class StructuredGroupingDefinition < Parameter::HashParameterDefinition
      attr_reader :arel_table, :predicates

      def initialize(*args, **opts)
        @predicates = {}
        super *args, **opts
      end

      def add_predicate(predicate)
        raise ParamsReadyError, "Predicate name taken: '#{predicate.name}" if predicates.key? predicate.name
        predicates[predicate.name] = predicate
      end

      parameter_class StructuredGrouping

      freeze_variables :predicates
    end
  end
end