require_relative '../error'
require_relative 'tendency'

module ParamsReady
  module Pagination
    module Nulls
      module First
        def self.if_null_predicate(column, nested)
          is_null_and_all = column.eq(nil).and(nested)
          grouping = Arel::Nodes::Grouping.new(is_null_and_all)
          is_not_null = column.not_eq(nil)
          grouping.or(is_not_null)
        end

        def self.if_not_null_predicate(tendency, column, value, nested)
          tendency.non_nullable_predicate(column, value, nested)
        end
      end

      module Last
        def self.if_null_predicate(column, nested)
          Arel::Nodes::Grouping.new(column.eq(nil).and(nested))
        end

        def self.if_not_null_predicate(tendency, column, value, nested)
          tendency.non_nullable_predicate(column, value, nested).or(column.eq(nil))
        end
      end
    end
  end
end