require_relative 'intent'

module ParamsReady
  class OutputParameters
    attr_reader :scoped_id, :parameter

    def method_missing(name, *args, &block)
      if @parameter.respond_to? name, false
        @parameter.send(name, *args, &block)
      else
        super
      end
    end

    def respond_to_missing?(name, include_private = false)
      if @parameter.respond_to? name, include_private
        true
      else
        super
      end
    end

    def self.decorate(parameter, *args)
      intent = case args.length
      when 0
        Intent.instance(:frontend)
      when 1
        Intent.resolve(args[0])
      when 2
        format = args[0]
        restriction = args[1]
        Intent.new format, restriction
      else
        msg = "ArgumentError: wrong number of arguments (given #{args.length + 1}, expected 1..3)"
        raise ParamsReadyError, msg
      end
      new parameter, intent
    end

    def initialize(parameter, intent, scoped_name = nil, scoped_id = nil)
      raise ParamsReadyError, "Expected parameter '#{parameter.name}' to be frozen" unless parameter.frozen?
      @parameter = parameter
      @intent = Intent.resolve(intent)
      @tree = {}
      @scoped_name = scoped_name || @intent.hash_key(parameter).to_s
      @scoped_id = scoped_id || @intent.hash_key(parameter).to_s
    end

    def scoped_name(multiple: false)
      return @scoped_name unless multiple
      @scoped_name + "[]"
    end

    def [](key)
      if @tree.key? key
        @tree[key]
      elsif @parameter.respond_to? :[]
        child = @parameter[key]
        formatted_name = if @parameter.definition.is_a? Parameter::ArrayParameterDefinition::ArrayLike
          key.to_s
        else
          @intent.hash_key(child).to_s
        end
        child_scoped_name = @scoped_name.empty? ? formatted_name : "#{@scoped_name}[#{formatted_name}]"
        child_scoped_id = @scoped_id.empty? ? formatted_name : "#{@scoped_id}_#{formatted_name}"
        intent = @parameter.intent_for_children(@intent)
        decorated = OutputParameters.new(child, intent, child_scoped_name, child_scoped_id)
        @tree[key] = decorated
        decorated
      else
        raise ParamsReadyError, "Parameter '#{@parameter.name}' doesn't support square brackets access"
      end
    end

    def flat_pairs(format = @intent.format, restriction: @intent.restriction, data: @intent.data)
      self.class.flatten_hash(for_output(format, restriction: restriction, data: data), scoped_name)
    end

    def self.flatten_hash(hash, scope)
      hash.flat_map do |key, value|
        nested = scope.empty? ? key.to_s : "#{scope}[#{key}]"
        if value.is_a? Hash
          flatten_hash(value, nested)
        else
          [[nested, value]]
        end
      end
    end

    def to_hash(format = @intent.format, restriction: nil, data: @intent.data)
      restriction = if restriction.nil?
        Restriction.permit(name => @intent.restriction)
      else
        restriction
      end
      @parameter.to_hash(format, restriction: restriction, data: data)
    end

    def for_output(format = @intent.format, restriction: @intent.restriction, data: @intent.data)
      @parameter.for_output(format, restriction: restriction, data: data)
    end

    def for_frontend(restriction: @intent.restriction, data: @intent.data)
      @parameter.for_frontend(restriction: restriction, data: data)
    end

    def for_model(format = :update, restriction: @intent.restriction)
      @parameter.for_model(format, restriction: restriction)
    end

    def format(format = @intent)
      @parameter.format(format)
    end

    def build_select(context: @intent.restriction, **opts)
      @parameter.build_select(context: context, **opts)
    end

    def build_relation(context: @intent.restriction, **opts)
      @parameter.build_relation(context: context, **opts)
    end

    def perform_count(context: @intent.restriction, **opts)
      @parameter.perform_count(context: context, **opts)
    end
  end
end
