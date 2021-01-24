require_relative '../parameter/tuple_parameter'
require_relative '../value/validator'
require_relative 'abstract_pagination'

module ParamsReady
  module Pagination
    class OffsetPagination < Parameter::TupleParameter
      include AbstractPagination

      def paginate_relation(relation, _, _)
        relation.offset(offset).limit(limit)
      end

      def paginate_query(query, _, _, _)
        query.skip(offset).take(limit)
      end

      def offset=(off)
        self.first.set_value off
      end

      def offset
        first.unwrap
      end

      def limit=(lmt)
        self.second.set_value lmt
      end

      def limit
        second.unwrap
      end

      def limit_key
        1
      end

      def page_no
        ((offset + limit - 1) / limit) + 1
      end

      def page_value(delta, count: nil)
        return nil unless can_yield_page?(delta, count: count)

        [new_offset(delta), limit]
      end

      def current_page_value
        page_value(0)
      end

      def previous_page_value(delta = 1)
        page_value(-delta)
      end

      def next_page_value(delta = 1, count: nil)
        page_value(delta, count: count)
      end

      def first_page_value
        [0, limit]
      end

      def last_page_value(count:)
        num_pages = num_pages(count: count)
        return nil if num_pages == 0

        new_offset = (num_pages - 1) * limit
        [new_offset, limit]
      end

      def new_offset(delta)
        shift = delta * limit
        no = offset + shift
        return no if no >= 0
        return 0 if shift.abs < offset + limit

        nil
      end

      def has_previous?(delta = 1)
        raise ParamsReadyError, 'Negative delta unexpected' if delta < 0
        return false if offset == 0

        delta * limit < offset + limit
      end

      def has_next?(delta = 1, count:)
        raise ParamsReadyError, 'Nil count unexpected' if count.nil?
        raise ParamsReadyError, 'Negative delta unexpected' if delta < 0

        offset + (delta * limit) < count
      end

      def has_page?(delta, count: nil)
        if delta > 0
          has_next? delta, count: count
        else
          has_previous? -delta
        end
      end

      def can_yield_page?(delta, count: nil)
        return true if delta >= 0 && count.nil?

        has_page?(delta, count: count)
      end
    end

    class OffsetPaginationDefinition < Parameter::TupleParameterDefinition
      MIN_LIMIT = 1
      parameter_class OffsetPagination

      def initialize(default_offset, default_limit, max_limit = nil)
        offset = Builder.define_integer(:offset, altn: :off) do
          constrain Value::OperatorConstraint.new(:>=, 0), strategy: :clamp
        end
        limit = Builder.define_integer(:limit, altn: :lmt) do
          constrain Value::OperatorConstraint.new(:>=, MIN_LIMIT), strategy: :clamp
          constrain Value::OperatorConstraint.new(:<=, max_limit), strategy: :clamp unless max_limit.nil?
        end
        super :pagination,
              altn: :pgn,
              marshaller: { using: :string, separator: '-' },
              fields: [offset, limit],
              default: [default_offset, default_limit]
      end
    end
  end
end
