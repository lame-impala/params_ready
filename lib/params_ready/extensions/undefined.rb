module ParamsReady
  module Extensions
    class Undefined
      def self.dup
        self
      end

      def self.value_indefinite?(value)
        value == self || value.nil?
      end

      freeze
    end
  end
end
