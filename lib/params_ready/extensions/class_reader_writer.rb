require_relative '../error'

module ParamsReady
  module Extensions
    module ClassReaderWriter
      def class_reader_writer(method_name)
        ivar = :"@#{method_name}"
        define_singleton_method method_name do |*args|
          if args.length == 0
            value = instance_variable_get(ivar)
            if value.nil?
              if superclass.respond_to? method_name
                superclass.send method_name
              else
                raise ParamsReadyError, "Class variable '#{ivar}' not set for '#{name}'"
              end
            else
              value
            end
          elsif args.length == 1
            if instance_variable_get(ivar).nil?
              instance_variable_set(ivar, args[0])
            else
              raise ParamsReadyError, "Class variable '#{ivar}' already set for '#{name}'"
            end
          else
            raise ParamsReadyError, "Unexpected parameters to '#{method_name}': #{args}"
          end
        end
      end
    end
  end
end
