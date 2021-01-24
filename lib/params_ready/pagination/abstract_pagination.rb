module ParamsReady
  module Pagination
    module AbstractPagination
      def num_pages(count:)
        raise ParamsReadyError, 'Negative count unexpected' if count < 0
        (count.to_f / limit.to_f).ceil.to_i
      end

      def first_page
        update_in(first_page_value, [])
      end

      def last_page(*args)
        update_in(last_page_value(*args), [])
      end
    end
  end
end
