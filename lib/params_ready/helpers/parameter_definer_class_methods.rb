require_relative 'relation_builder_wrapper'
require_relative '../builder'

module ParamsReady
  module Helpers
    module ParameterDefinerClassMethods
      def define_relation(*args, **opts, &block)
        wrapper = ParamsReady::Helpers::RelationBuilderWrapper.new self, *args, **opts
        wrapper.instance_eval(&block) unless block.nil?
        relation = wrapper.build
        params_ready_storage.add_relation relation
      end

      def define_parameter(type, *args, **opts, &block)
        full_name = "define_#{type}"
        parameter = Builder.send(full_name, *args, **opts, &block)
        params_ready_storage.add_parameter parameter
      end

      def all_relations
        relations = if superclass.respond_to? :all_relations
          superclass.all_relations
        else
          {}
        end
        relations.merge(params_ready_storage.relations)
      end

      def all_parameters
        parameters = if superclass.respond_to? :all_parameters
          superclass.all_parameters
        else
          {}
        end
        parameters.merge(params_ready_storage.parameters)
      end
    end
  end
end