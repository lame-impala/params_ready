require_relative '../parameter/hash_parameter'
require_relative '../parameter/array_parameter'
require_relative 'grouping'
require_relative 'predicate'

module ParamsReady
  module Query
    class ArrayGrouping < Parameter::HashParameter
      include Parameter::GroupingLike

      def predicates
        self[:array].to_a
      end

      def operator
        self[:operator].unwrap
      end

      def context_for_predicates(restriction)
        restriction.for_children(self)
      end

      def to_query(arel_table, context: Restriction.blanket_permission)
        array = self[:array]

        context = array.intent_for_children(context)
        super arel_table, context: context
      end
    end

    class ArrayGroupingBuilder < Builder
      include Parameter::AbstractHashParameterBuilder::HashLike
      PredicateRegistry.register_predicate :array_grouping_predicate, self

      def prototype(type_name, name = :proto, *arr, **opts, &block)
        prototype = PredicateRegistry.predicate(type_name).instance(name, *arr, **opts)
        prototype.instance_eval(&block) unless block.nil?
        @definition.set_prototype prototype.build
      end

      def self.instance(name, altn: nil)
        new ArrayGroupingDefinition.new(name, altn: altn)
      end

      def operator(&block)
        definition = Builder.define_grouping_operator(:operator, altn: :op, &block)
        add definition
      end
    end

    class ArrayGroupingDefinition < Parameter::HashParameterDefinition
      def initialize(*args, **opts)
        super
      end

      late_init :prototype, getter: false, obligatory: false do |prototype|
        array = Builder.define_array(:array, altn: :a) do
          prototype(prototype)
          default []
        end
        add_child array
        Extensions::Undefined
      end

      parameter_class ArrayGrouping
    end
  end
end