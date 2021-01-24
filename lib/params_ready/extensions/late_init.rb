require_relative '../error'

module ParamsReady
  module Extensions
    module LateInit
      def late_init(
        name,
        obligatory: true,
        freeze: true,
        getter: true,
        boolean: false,
        once: true,
        definite: true,
        &block
      )
        ivar = :"@#{name}"
        define_method "set_#{name}" do |value|
          raise ParamsReadyError, "Can't initialize '#{name}' to nil" if value.nil? && definite
          value = instance_exec(value, &block) unless block.nil?
          next if value == Extensions::Undefined

          current = instance_variable_get ivar
          raise ParamsReadyError, "Variable '#{name}' already set" unless current.nil? || !once
          value.freeze if freeze
          instance_variable_set "@#{name}", value
        end

        if boolean
          define_method "#{name}?" do
            instance_variable_get ivar
          end
        end
        attr_reader name if getter
        obligatory! name if obligatory
      end
    end
  end
end
