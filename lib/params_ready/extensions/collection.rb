require_relative '../error'

module ParamsReady
  module Extensions
    module Collection
      def collection(
        collection_name,
        element_name,
        freeze_collection: true,
        freeze_value: true,
        getter: true,
        obligatory: false,
        &block
      )
        full_name = "@#{collection_name}"
        define_method "add_#{element_name}" do |value|
          value = instance_exec(value, &block) unless block.nil?
          next if value == Extensions::Undefined

          collection = send collection_name
          value.freeze if freeze_value
          collection << value
        end

        if getter
          define_method collection_name do
            if instance_variable_defined? full_name
              instance_variable_get full_name
            elsif frozen?
              [].freeze
            else
              instance_variable_set full_name, []
              instance_variable_get full_name
            end
          end
        end

        obligatory! collection_name if obligatory
        freeze_variable collection_name if freeze_collection
      end
    end
  end
end
