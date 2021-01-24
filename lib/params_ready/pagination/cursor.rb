require_relative '../helpers/arel_builder'
require_relative '../../arel/cte_name'

module ParamsReady
  module Pagination
    class CursorBuilder
      def initialize(keyset, arel_table, context)
        @keyset = keyset.freeze
        @arel_table = arel_table
        @context = context
        @select_list = []
      end

      def add(key, column)
        attribute = if @keyset.key? key
          Literal.new(key, @keyset[key], column.pk)
        else
          Selector.new(key, column)
        end

        @select_list << attribute
      end

      def build
        cursor = Cursor.new(@select_list, @arel_table, @context)
        @select_list = nil
        freeze
        cursor
      end

      class Selector
        attr_reader :key
        attr_reader :column

        def initialize(key, column)
          @key = key
          @column = column
          freeze
        end

        def expression(arel_table, context)
          column.attribute(key, arel_table, context)
        end

        def rvalue(cte)
          cte.project(key)
        end
      end

      class Literal
        attr_reader :key
        attr_reader :pk

        def initialize(key, value, pk)
          @key = key
          @value = Arel::Nodes::Quoted.new(value)
          @pk = pk
          freeze
        end

        def quoted
          @value
        end

        def value
          @value.value
        end

        def rvalue(_)
          @value
        end
      end

      class Cursor
        attr_reader :select_list, :selectors, :literals, :cte

        def initialize(select_list, arel_table, context)
          @hash = select_list_to_hash(select_list)
          @selectors, @literals = select_list.partition { |attr| attr.is_a? Selector }
          @arel_table = arel_table
          @context = context
          names = column_names(@selectors)
          @cte_ref = Arel::Table.new(cte_reference(names))
          @cte_def = cte_definition(@cte_ref, names)

          freeze
        end

        def select_list_to_hash(select_list)
          res = select_list.each_with_object({}) do |item, hash|
            raise ParamsReadyError, "Repeated key in select list: '#{item.key}'" if hash.key? item.key

            hash[item.key] = item
          end
          res.freeze
        end

        def cte_for_relation(relation)
          return nil if selectors.empty?

          expressions = column_expressions(selectors)
          relation = relation.where(**active_record_predicates(literals))
                             .select(*expressions)
          select = Arel::Nodes::SqlLiteral.new(relation.to_sql)
          grouping = Arel::Nodes::Grouping.new(select)
          as = Arel::Nodes::As.new(@cte_def, grouping)
          Arel::Nodes::With.new([as])
        end

        def cte_for_query(query, arel_table)
          return nil if selectors.empty?

          query = query.deep_dup
          expressions = column_expressions(selectors)
          query = query.where(arel_predicates(literals, arel_table))
                       .project(*expressions)
          grouping = Arel::Nodes::Grouping.new(query)
          Arel::Nodes::As.new(@cte_def, grouping)
        end

        def active_record_predicates(literals)
          literals.select do |literal|
            literal.pk
          end.map do |literal|
            [literal.key, literal.value]
          end.to_h
        end

        def arel_predicates(literals, arel_table)
          literals.reduce(nil) do |query, literal|
            next query unless literal.pk

            predicate = arel_table[literal.key].eq(literal.quoted)
            next predicate if query.nil?

            query.and(predicate)
          end
        end

        def column_names(selectors)
          selectors.lazy.map(&:key).map(&:to_s).force
        end

        def column_expressions(selectors)
          selectors.map do |selector|
            selector.expression(@arel_table, @context)
          end
        end

        def cte_reference(names)
          unsafe_name = "#{names.join('_')}_cte"
          Helpers::ArelBuilder.safe_name(unsafe_name)
        end

        def cte_definition(reference, names)
          node = Arel::Nodes::SqlLiteral.new(names.join(', '))
          grouping = Arel::Nodes::Grouping.new(node)
          # The name must be literal, otherwise
          # it will be quoted by the visitor
          expression = "#{reference.name} #{grouping.to_sql}"

          Arel::Nodes::CteName.new(expression)
        end

        def rvalue(key)
          @hash[key].rvalue(@cte_ref)
        end
      end
    end
  end
end