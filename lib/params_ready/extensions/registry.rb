module ParamsReady
  module Extensions
    module Registry
      def registry(registry_name, name_method: nil, as: nil, getter: false, &block)
        class_variable_name = "@@#{registry_name}"

        class_variable_set class_variable_name, {}
        if as
          if name_method.nil?
            define_singleton_method "register_#{as}" do |name, entry|
              registry = class_variable_get class_variable_name
              raise ParamsReadyError, "Name '#{name}' already taken for '#{human_string(as)}'" if registry.key? name
              instance_exec name, entry, &block unless block.nil?
              registry[name] = entry
            end
          else
            define_singleton_method "register_#{as}" do |entry|
              name = entry.send name_method
              registry = class_variable_get class_variable_name
              raise ParamsReadyError, "Name '#{name}' already taken for '#{human_string(as)}'" if registry.key? name
              instance_exec name, entry, &block unless block.nil?
              registry[name] = entry
            end
          end
        end
        if getter
          define_singleton_method as do |name|
            registry = class_variable_get class_variable_name
            raise ParamsReadyError, "Name '#{name}' not found in #{human_string(registry_name)}" unless registry.key? name
            registry[name]
          end
        end
        define_singleton_method "has_#{as}?" do |name|
          registry = class_variable_get class_variable_name
          registry.key? name
        end
      end

      def human_string(string)
        string.to_s.gsub("_", " ")
      end
    end
  end
end