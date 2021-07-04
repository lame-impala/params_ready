module ParamsReady
  module Helpers
    class Callable
      def initialize(&block)
        @block = block
        freeze
      end

      def call
        @block.call
      end
    end
  end
end
