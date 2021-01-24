module ParamsReady
  module Marshaller
    module BuilderModule
      def marshal(to: nil, using: nil, **opts)
        @definition.set_marshaller(to: to, using: using, **opts)
      end
    end
  end
end