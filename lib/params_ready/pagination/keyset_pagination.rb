require_relative '../parameter/struct_parameter'
require_relative '../value/constraint'
require_relative '../helpers/arel_builder'
require_relative 'abstract_pagination'
require_relative 'direction'

module ParamsReady
  module Pagination
    class KeysetPagination < Parameter::StructParameter
      include AbstractPagination

      def select_keysets(query, limit, direction, keyset, ordering, arel_table, context)
        query = keyset_query(query, limit, direction, keyset, ordering, arel_table, context)
        query.project(*cursor_columns_arel(ordering, arel_table, context))
      end

      def keyset_query(query, limit, direction, keyset, ordering, arel_table, context)
        cursor, grouping = cursor_predicates(direction, keyset, ordering, arel_table, context)
        cte = cursor.cte_for_query(query, arel_table) unless cursor.nil?
        query = query.where(grouping) unless grouping.nil?

        query = query.with(cte) unless cte.nil?
        ordered = query.order(ordering_arel(direction, ordering, arel_table, context))
        ordered.take(limit)
      end

      def keysets_for_relation(relation, limit, direction, keyset, ordering, context)
        arel_table = relation.arel_table

        cursor, predicates = cursor_predicates(direction, keyset, ordering, arel_table, context)
        full_query = relation.where(predicates)
                             .reorder(ordering_arel(direction, ordering, arel_table, context))
                             .limit(limit)
                             .select(*cursor_columns_arel(ordering, arel_table, context))
        full_query = Arel::Nodes::SqlLiteral.new(full_query.to_sql)
        with_cte(relation, full_query, cursor)
      end

      def paginate_relation(relation, ordering, context)
        arel_table = relation.arel_table
        cursor, predicates = cursor_predicates(direction, keyset, ordering, arel_table, context)

        subselect = relation.where(predicates)
                            .reorder(ordering_arel(direction, ordering, arel_table, context))
                            .limit(limit)
                            .select(primary_keys_arel(ordering, arel_table, context))

        subselect_sql = Arel::Nodes::SqlLiteral.new(subselect.to_sql)
        subselect_sql = with_cte_grouped(relation, subselect_sql, cursor)

        exists = exists_predicate(subselect_sql, ordering, arel_table)
        relation.where(exists)
      end

      def paginate_query(query, ordering, arel_table, context)
        cursor, predicates = cursor_predicates(direction, keyset, ordering, arel_table, context)
        cte = cursor.cte_for_query(query, arel_table) unless cursor.nil?
        subquery = query.deep_dup
        subquery = subquery.where(predicates) unless predicates.nil?
        subquery = subquery.with(cte) unless cte.nil?

        subselect = subquery.order(ordering_arel(direction, ordering, arel_table, context))
          .take(limit)
          .project(primary_keys_arel(ordering, arel_table, context))

        exists = exists_predicate(subselect, ordering, arel_table)
        query.where(exists)
      end

      def exists_predicate(subselect, ordering, arel_table)
        table_alias = self.table_alias(arel_table)
        aliased = arel_table.alias(table_alias)
        select_manager = Arel::SelectManager.new.from(subselect.as(table_alias))
        related = related_clause(arel_table, aliased, ordering.definition.primary_keys)
        select_manager.where(related).project('1').exists
      end

      def related_clause(arel_table, aliased, primary_keys)
        cursor_columns.reduce(nil) do |clause, name|
          next clause unless primary_keys.member?(name)

          predicate = arel_table[name].eq(aliased[name])
          next predicate if clause.nil?

          next clause.and(predicate)
        end
      end

      def with_cte_grouped(relation, select, cursor)
        with_cte = with_cte(relation, select, cursor)
        Arel::Nodes::Grouping.new(with_cte)
      end

      def with_cte(relation, select, cursor)
        return select if cursor.nil?

        cte = cursor.cte_for_relation(relation)
        return select if cte.nil?

        Arel::Nodes::SqlLiteral.new([cte.to_sql, select].join(' '))
      end

      def table_alias(arel_table)
        Helpers::ArelBuilder.safe_name "#{arel_table.name}_#{cursor_columns.join('_')}"
      end

      def ordering_arel(direction, ordering, arel_table, context)
        inverted = Direction.instance(direction).invert_ordering?
        ordering.to_arel(arel_table, context: context, inverted: inverted)
      end

      def cursor_predicates(direction, keyset, ordering, arel_table, context)
        direction = Direction.instance(direction)
        direction.cursor_predicates(keyset, ordering, arel_table, context)
      end

      def first_page_value
        { limit: limit, direction: :aft, keyset: {} }
      end

      def last_page_value
        { limit: limit, direction: :bfr, keyset: {} }
      end

      def before_page_value(keyset)
        keyset ||= {}
        { limit: limit, direction: :bfr, keyset: keyset }
      end

      def after_page_value(keyset)
        keyset ||= {}
        { limit: limit, direction: :aft, keyset: keyset }
      end

      def limit
        self[:limit].unwrap
      end

      def limit_key
        :limit
      end

      def direction
        self[:direction].unwrap
      end

      def keyset
        self[:keyset].unwrap
      end

      def cursor_columns
        self[:keyset].names.keys
      end

      def cursor_columns_arel(ordering, arel_table, context, columns: cursor_columns)
        columns.map do |name|
          column = ordering.definition.columns[name]
          column.attribute(name, arel_table, context)
        end
      end

      def primary_keys_arel(ordering, arel_table, context)
        columns = cursor_columns.lazy.select do |name|
          ordering.definition.primary_keys.member? name
        end

        cursor_columns_arel(ordering, arel_table, context, columns: columns).force
      end

      def cursor
        return nil unless is_definite?

        keyset = self[:keyset]
        keyset.names.keys.map do |column_name|
          keyset[column_name].unwrap
        end
      end
    end

    class KeysetPaginationDefinition < Parameter::StructParameterDefinition
      MIN_LIMIT = 1

      parameter_class KeysetPagination

      attr_reader :default_limit

      def initialize(default_limit, max_limit = nil)
        super :pagination,
              altn: :pgn

        @default_limit = default_limit

        direction = Builder.define_symbol(:direction, altn: :dir) do
          constrain :enum, [:bfr, :aft]
        end

        limit = Builder.define_integer(:limit, altn: :lmt) do
          constrain Value::OperatorConstraint.new(:>=, MIN_LIMIT), strategy: :clamp
          constrain Value::OperatorConstraint.new(:<=, max_limit), strategy: :clamp unless max_limit.nil?
        end
        add_child(direction)
        add_child(limit)
      end

      def finish
        keyset = names[:keyset]
        raise ParamsReadyError, "No cursor defined" if keyset.nil? || keyset.names.length < 1
        super
      end
    end

    class KeysetPaginationBuilder
      def initialize(ordering_builder, default_limit, max_limit = nil)
        definition = KeysetPaginationDefinition.new(default_limit, max_limit)
        @cursor_builder = Parameter::StructParameterBuilder.send :new, definition
        @default = {
          limit: default_limit,
          direction: :aft,
          keyset: {}
        }
        @ordering_builder = ordering_builder
        @keyset = Parameter::StructParameterBuilder.instance(:keyset, altn: :ks)
      end

      def key(type, name, direction, &block)
        add_to_cursor(type, name, &block)
        @ordering_builder.column name, direction, required: true, pk: true
      end

      def column(type, name, direction, **opts, &block)
        add_to_cursor(type, name, &block)
        @ordering_builder.column name, direction, **opts
      end

      def base64
        @cursor_builder.marshal using: :base64
      end

      def add_to_cursor(type, name, &block)
        @keyset.add type, name do
          optional
          include(&block) unless block.nil?
        end
      end

      def build(&block)
        instance_eval(&block)
        @cursor_builder.add @keyset.build
        @cursor_builder.default @default
        @cursor_builder.build
      end
    end
  end
end
