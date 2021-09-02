require_relative 'predicate'
require_relative 'structured_grouping'
require_relative 'join_clause'

module ParamsReady
  module Query
    class ExistsPredicate < StructuredGrouping
      include Predicate::HavingAssociations

      def to_query(query_table, context: Restriction.blanket_permission)
        query_table = definition.outer_table || query_table

        subquery_table = self.definition.arel_table
        raise ParamsReadyError, "Arel table for '#{name}' not set" if subquery_table.nil?

        predicates = predicate_group(subquery_table, context: context)

        join_clause = self.related query_table, subquery_table, context
        subquery = GroupingOperator.instance(:and).connect(predicates, join_clause)
        select = subquery_table.where(subquery)
        query = select.take(1).project(Arel.star).exists
        if definition.has_child?(:existence) && self[:existence].unwrap == :none
          query.not
        else
          query
        end
      end

      def related(query_table, subquery_table, context)
        return nil if definition.related.nil?

        grouping = definition.related.to_arel(query_table, subquery_table, context, self)
        subquery_table.grouping(grouping)
      end

      def test(record)
        return nil unless is_definite?

        collection = dig(record, definition.path_to_collection)

        result = if collection.nil?
          false
        else
          collection.any? do |item|
            super item
          end
        end

        if definition.has_child?(:existence) && self[:existence].unwrap == :none
          !result
        else
          result
        end
      end
    end

    class ExistsPredicateBuilder < Builder
      PredicateRegistry.register_predicate :exists_predicate, self

      include GroupingLike
      include Parameter::AbstractStructParameterBuilder::StructLike
      include HavingArelTable

      def self.instance(name, altn: nil, coll: nil)
        new ExistsPredicateDefinition.new(name, altn: altn, path_to_collection: Array(coll))
      end

      def related(on: nil, eq: nil, &block)
        join_statement = JoinStatement.new(on: on, eq: eq, &block)
        @definition.set_related(join_statement)
      end

      def outer_table(arel_table)
        @definition.set_outer_table arel_table
      end

      def existence(&block)
        definition = Builder.define_symbol(:existence, altn: :ex) do
          constrain :enum, [:some, :none]
          include &block
        end
        add definition
      end
    end

    class ExistsPredicateDefinition < StructuredGroupingDefinition
      late_init :outer_table, obligatory: false, freeze: false
      late_init :arel_table, obligatory: false, freeze: false
      late_init :related, obligatory: false, freeze: true

      def initialize(*args, path_to_collection: nil, **opts)
        @path_to_collection = path_to_collection
        super *args, **opts
      end

      def path_to_collection
        @path_to_collection || [@name]
      end

      parameter_class ExistsPredicate
    end
  end
end