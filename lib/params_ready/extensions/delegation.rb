module ParamsReady
  module Extensions
    module Delegation
      def self.delegate(mod, &to)
        mod.define_method :method_missing do |name, *args, &block|
          delegee = instance_eval(&to)
          if delegee.respond_to? name
            delegee.send name, *args, &block
          else
            super name, *args, &block
          end
        end

        mod.define_method :respond_to_missing? do |name, include_private = false|
          delegee = instance_eval(&to)
          if delegee.respond_to? name
            true
          else
            super name, include_private
          end
        end
      end
    end
  end
end
