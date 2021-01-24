require_relative 'helpers/parameter_definer_class_methods'
require_relative 'helpers/parameter_storage_class_methods'
require_relative 'helpers/relation_builder_wrapper'

module ParamsReady
  module ParameterDefiner
    def self.included(base)
      base.extend(Helpers::ParameterStorageClassMethods)
      base.extend(Helpers::ParameterDefinerClassMethods)
    end
  end
end


