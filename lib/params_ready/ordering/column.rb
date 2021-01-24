require_relative '../error'
require_relative '../helpers/arel_builder'

module ParamsReady
  module Ordering
    class Column
      DIRECTIONS = Set.new %i(none asc desc)

      attr_reader :ordering, :table, :nulls, :required, :pk

      NULLS_FIRST = { null: 0, not_null: 1 }.freeze
      NULLS_LAST = { null: 1, not_null: 0 }.freeze

      def initialize(ordering, arel_table:, expression:, nulls: :default, required: false, pk: false)
        raise ParamsReadyError, "Invalid ordering value: #{ordering}" unless DIRECTIONS.include? ordering
        @ordering = ordering
        @table = arel_table
        @expression = expression
        @nulls = nulls
        @required = required
        @pk = pk
      end

      def expression(name)
        @expression || name
      end

      def attribute(name, default_table, context)
        arel_table = table || default_table
        arel_builder = Helpers::ArelBuilder.instance(expression(name), arel_table: arel_table)
        arel_builder.to_arel(arel_table, context, self)
      end

      def clauses(attribute, direction, inverted: false)
        clause = attribute.send direction
        if nulls == :default
          [clause]
        else
          values = null_substitution_values(nulls, inverted)

          nulls_last = Arel::Nodes::Case.new
            .when(attribute.eq(nil)).then(values[:null])
            .else(values[:not_null])
          [nulls_last, clause]
        end
      end

      def null_substitution_values(policy, inverted)
        case [policy, inverted]
        when [:first, false], [:last, true]
          NULLS_FIRST
        when [:last, false], [:first, true]
          NULLS_LAST
        else
          raise ParamsReadyError, "Unimplemented null handling policy: '#{nulls}' (inverted: #{inverted})"
        end
      end
    end
  end
end