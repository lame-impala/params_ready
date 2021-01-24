module ParamsReady
  module Extensions
    module Finalizer
      def obligatory!(*args)
        obligatory.concat args
      end

      def obligatory
        @obligatory ||= []
      end

      module InstanceMethods
        def finish
          self.class.obligatory.each do |name|
            value = instance_variable_get("@#{name}")
            raise ParamsReadyError, "Obligatory property is nil: #{name}" if value.nil?
            if value.respond_to? :empty? and value.empty?
              raise ParamsReadyError, "Obligatory property is empty: #{name}"
            end
          end
          self
        end
      end
    end
  end
end
