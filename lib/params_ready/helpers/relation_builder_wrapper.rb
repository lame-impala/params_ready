require_relative '../query/relation'

module ParamsReady
  module Helpers
    class RelationBuilderWrapper
      def initialize(cache, *args, **opts)
        @cache = cache
        @builder = Query::RelationParameterBuilder.instance *args, **opts
      end

      def capture(*names)
        names.each do |name|
          definition = @cache.parameter_definition(name)
          @builder.add definition
        end
      end

      ruby2_keywords def method_missing(name, *args, &block)
        if @builder.respond_to? name
          @builder.send name, *args, &block
        else
          super
        end
      end

      def respond_to_missing?(name, include_private = false)
        if @builder.respond_to? name
          true
        else
          super
        end
      end
    end
  end
end