require_relative 'storage'
require_relative '../error'

module ParamsReady
  module Helpers
    module ParameterStorageClassMethods
      def params_ready_storage
        @params_ready_storage ||= Storage.new
      end

      def relation_definition(key)
        relations = params_ready_storage.relations
        sym_key = key.to_sym
        if relations.key?(sym_key)
          relations[sym_key]
        elsif superclass.respond_to? :relation_definition
          superclass.relation_definition sym_key
        else
          raise ParamsReadyError, "Unknown relation '#{sym_key}'"
        end
      end

      def parameter_definition(key)
        parameters = params_ready_storage.parameters
        sym_key = key.to_sym
        if parameters.key? sym_key
          parameters[sym_key]
        elsif superclass.respond_to? :parameter_definition
          superclass.parameter_definition sym_key
        else
          raise ParamsReadyError, "Unknown parameter '#{sym_key}'"
        end
      end

      def include_parameters(parameter_definer)
        parameter_definer.all_parameters.values.each do |p|
          params_ready_storage.add_parameter(p)
        end
      end

      def include_relations(parameter_definer)
        parameter_definer.all_relations.values.each do |d|
          params_ready_storage.add_relation(d)
        end
      end
    end
  end
end
