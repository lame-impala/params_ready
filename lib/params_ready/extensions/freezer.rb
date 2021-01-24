module ParamsReady
  module Extensions
    module Freezer
      def variables_to_freeze
        # This works on assumption classes
        # are not redefined during runtime
        @cached_variables_to_freeze ||= begin
          names = if defined? @variables_to_freeze
            @variables_to_freeze.dup
          else
            []
          end
          names += superclass.variables_to_freeze if superclass.respond_to? :variables_to_freeze
          names
        end
      end

      def freeze_variable(name, &block)
        ivar = :"@#{name}"
        if defined? @variables_to_freeze
          @variables_to_freeze << [ivar, block]
        else
          @variables_to_freeze = [[ivar, block]]
          define_method :freeze_variables do
            next if frozen?
            self.class.variables_to_freeze.each do |(ivar, block)|
              variable = instance_variable_get ivar
              block.call(variable) unless block.nil?
              variable.freeze
            end
          end
        end
      end

      def freeze_variables(*names)
        names.each do |name|
          freeze_variable name
        end
      end

      module InstanceMethods
        def freeze
          freeze_variables if respond_to? :freeze_variables
          super
        end
      end
    end
  end
end
