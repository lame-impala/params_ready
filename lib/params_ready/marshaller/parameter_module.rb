module ParamsReady
  module Marshaller
    module ParameterModule
      def marshal(intent)
        return nil if is_nil?

        definition.marshal(self, intent)
      end
    end
  end
end
