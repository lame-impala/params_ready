require_relative '../error'
require_relative 'tendency'
require_relative 'nulls'
require_relative 'cursor'
require_relative 'keysets'

module ParamsReady
  module Pagination
    module Direction
      def self.instance(dir)
        case dir
        when :bfr, :before then Before
        when :aft, :after then After
        else
          raise ParamsReadyError, "Unexpected direction: '#{dir}'"
        end
      end

      def cursor_predicates(keyset, ordering, arel_table, context)
        primary_keys = ordering.definition.primary_keys.dup
        return [nil, nil] unless check_primary_keys_presence(keyset, primary_keys)

        cursor = build_cursor(keyset, ordering, arel_table, context)
        columns = ordering.to_array_with_context(context)

        predicate = cursor_predicate(columns, cursor, ordering, arel_table, context, primary_keys)
        grouping = Arel::Nodes::Grouping.new(predicate)
        [cursor, grouping]
      end

      def check_primary_keys_presence(keyset, primary_keys)
        primary_keys.all? do |pk|
          keyset.key?(pk) && !keyset[pk].nil?
        end
      end

      def cursor_predicate(columns, cursor, ordering, arel_table, context, primary_keys)
        tuple, *rest = columns
        key, column_ordering = tuple
        column = ordering.definition.columns[key]

        value_expression = cursor.rvalue(key)
        column_expression = column.attribute(key, arel_table, context)

        primary_keys.delete(key) if column.pk

        if column.pk && primary_keys.empty?
          pk_predicate(column_ordering, column_expression, value_expression)
        else
          nested = cursor_predicate(rest, cursor, ordering, arel_table, context, primary_keys)
          if column.nulls == :default
            non_nullable_predicate(column_ordering, column_expression, value_expression, nested)
          else
            nullable_predicate(column_ordering, column.nulls, column_expression, value_expression, nested)
          end
        end
      end

      def build_cursor(keyset, ordering, arel_table, context)
        builder = CursorBuilder.new(keyset, arel_table, context)
        ordering.to_array_with_context(context).each do |(key, _)|
          column = ordering.definition.columns[key]
          builder.add(key, column)
        end
        builder.build
      end

      def pk_predicate(ordering, column, value)
        tendency(ordering).comparison_predicate(column, value)
      end

      def non_nullable_predicate(ordering, column, value, nested)
        tendency(ordering).non_nullable_predicate(column, value, nested)
      end

      def nullable_predicate(ordering, nulls, column, value, nested)
        strategy = nulls_strategy(nulls)
        if_null = strategy.if_null_predicate(column, nested)
        tendency = tendency(ordering)
        expression = Arel::Nodes::Grouping.new(value)
        if_not_null = strategy.if_not_null_predicate(tendency, column, value, nested)
        Arel::Nodes::Case.new.when(expression.eq(nil))
                             .then(if_null)
                             .else(if_not_null)
      end

      module Before
        extend Direction

        def self.invert_ordering?
          true
        end

        def self.tendency(ordering)
          case ordering
          when :desc then Tendency::Growing
          when :asc then Tendency::Falling
          else
            raise ParamsReadyError, "Unexpected ordering: '#{ordering}'"
          end
        end

        def self.nulls_strategy(strategy)
          case strategy
          when :first then Nulls::Last
          when :last then Nulls::First
          else
            raise ParamsReadyError, "Unexpected nulls strategy: '#{strategy}'"
          end
        end

        def self.keysets(_, keysets, &block)
          BeforeKeysets.new(keysets, &block)
        end
      end

      module After
        extend Direction

        def self.invert_ordering?
          false
        end

        def self.tendency(ordering)
          case ordering
          when :asc then Tendency::Growing
          when :desc then Tendency::Falling
          else
            raise ParamsReadyError, "Unexpected ordering: '#{ordering}'"
          end
        end

        def self.nulls_strategy(strategy)
          case strategy
          when :first then Nulls::First
          when :last then Nulls::Last
          else
            raise ParamsReadyError, "Unexpected nulls strategy: '#{strategy}'"
          end
        end

        def self.keysets(last, keysets, &block)
          AfterKeysets.new(last, keysets, &block)
        end
      end
    end
  end
end