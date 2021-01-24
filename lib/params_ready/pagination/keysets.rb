module ParamsReady
  module Pagination
    class AbstractKeysets
      attr_reader :keysets

      def initialize(keysets, &block)
        @keysets = keysets
        @transform = block
      end

      def length
        @keysets.length
      end

      def transform(raw)
        return raw if @transform.nil?
        @transform.call(raw)
      end
    end

    class BeforeKeysets < AbstractKeysets
      def page(delta, limit)
        raise "Expected positive integer for limit, got: #{limit}" if limit < 1
        raise "Expected non-negative integer for delta, got: #{delta}" if delta < 0

        if delta == 0
          transform(@keysets.first)
        else
          shift = delta * limit
          diff = @keysets.length - shift
          if diff > 0
            transform(@keysets[shift])
          elsif diff.abs < limit
            {}
          else
            nil
          end
        end
      end
    end

    class AfterKeysets < AbstractKeysets
      attr_reader :last

      def initialize(last, keysets, &block)
        @last = last
        super keysets, &block
      end

      def page(delta, limit)
        raise "Expected positive integer for limit, got: #{limit}" if limit < 1
        raise "Expected positive integer for delta, got: #{delta}" if delta < 1
        return if @keysets.length.zero?

        shift = (delta - 1) * limit

        if shift == 0
          @last
        else
          diff = @keysets.length - shift
          if diff < 1
            nil
          else
            transform(@keysets[shift - 1])
          end
        end
      end
    end
  end
end