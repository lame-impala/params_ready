module ParamsReady
  module Pagination
    module Tendency
      def non_nullable_predicate(column, value, nested)
        if_equal = column.eq(value).and(nested)
        grouping = Arel::Nodes::Grouping.new(if_equal)
        comparison = comparison_predicate(column, value)
        grouping.or(comparison)
      end

      module Growing
        extend Tendency

        def self.comparison_predicate(column, value)
          column.gt(value)
        end
      end

      module Falling
        extend Tendency

        def self.comparison_predicate(column, value)
          column.lt(value)
        end
      end
    end
  end
end