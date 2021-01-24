module ParamsReady
  class Restriction
    module Wrapper
      extend Forwardable
      attr_reader :restriction
      def_delegators :restriction, :name_permitted?, :permitted?, :permissions_for

      def delegate(*args)
        return self if @restriction.everything?

        new_restriction = @restriction.delegate(*args)
        clone(restriction: new_restriction)
      end

      def for_children(parameter)
        return self if @restriction.everything?

        new_restriction = @restriction.for_children parameter
        clone(restriction: new_restriction)
      end

      def permit_all
        return self if @restriction.everything?

        clone(restriction: Restriction.blanket_permission)
      end

      def permit(*list)
        restriction = Restriction.permit(*list)
        return self if @restriction.everything? && restriction.everything?

        clone(restriction: restriction)
      end

      def prohibit(*list)
        restriction = Restriction.prohibit(*list)
        return self if @restriction.everything? && restriction.everything?

        clone(restriction: restriction)
      end

      def to_restriction
        @restriction
      end
    end

    class Everything
      def self.key?(_)
        true
      end

      def self.[](_)
        Everything
      end

      def self.dup
        self
      end
    end

    class Nothing
      def self.key?(_)
        false
      end

      def self.[](_)
        Nothing
      end

      def self.dup
        self
      end
    end

    def self.blanket_permission
      @blanket_permission ||= Allowlist.new
    end

    def self.permit(*args)
      Allowlist.instance(*args)
    end

    def self.prohibit(*args)
      Denylist.instance(*args)
    end

    def self.from_array(arr)
      arr.each_with_object({}) do |element, restriction|
        case element
        when String, Symbol
          restriction[element.to_sym] = Everything
        when Hash
          element.each do |key, value|
            restriction[key.to_sym] = value
          end
        else
          raise TypeError.new("Unexpected as restriction item: #{element}")
        end
      end
    end

    def self.instance(*list)
      return blanket_permission if list.length == 1 && list[0] == default

      restriction_list = if list.length == 1 && list[0].is_a?(Regexp)
        list[0]
      else
        from_array(list)
      end
      new restriction_list
    end

    attr_reader :restriction

    def initialize(restriction = self.class.default)
      @restriction = if restriction.is_a? self.class
        restriction.restriction
      else
        restriction.freeze
      end
      freeze
    end

    def hash
      @restriction.hash
    end

    def everything?
      @restriction == self.class.default
    end

    def name_listed?(name)
      if @restriction.is_a? Regexp
        name =~ @restriction
      else
        @restriction.key?(name)
      end
    end

    def permitted?(parameter)
      name = parameter.name
      return false unless name_permitted?(name)
      return true unless parameter.respond_to? :permission_depends_on

      children = parameter.permission_depends_on
      intent = parameter.intent_for_children(self)
      children.all? do |child|
        intent.permitted?(child)
      end
    end

    def delegate(parent, delegate_name, *others)
      return self if everything?

      list = restriction_list_for(parent)

      self.class.instance({ delegate_name => list }, *others)
    end

    def for_children(parameter)
      return self if everything?

      list = restriction_list_for(parameter)
      if list.is_a? Restriction
        list
      else
        self.class.instance(*list)
      end
    end

    def restriction_list_for(parameter)
      name = parameter.name
      raise ParamsReadyError, "Parameter '#{name}' not permitted" unless name_permitted? name
      restriction_list_for_name(name)
    end

    def to_restriction
      self
    end

    def permit_all
      self.class.permit_all
    end

    def self.permit_all
      new default
    end

    class Allowlist < Restriction
      def self.default
        Everything
      end

      def name_permitted?(name)
        name_listed?(name)
      end

      def permit(*args)
        self.class.permit(*args)
      end

      def ==(other)
        return false unless other.is_a? self.class
        return true if object_id == other.object_id

        restriction == other.restriction
      end

      protected

      def restriction_list_for_name(name)
        if @restriction.is_a? Regexp
          self.class.default
        else
          @restriction[name]
        end
      end
    end

    class Denylist < Restriction
      def self.default
        Nothing
      end

      def name_permitted?(name)
        return true unless name_listed?(name)
        return false unless @restriction.is_a?(Hash)
        return true if @restriction[name].is_a?(Array)
        return true if @restriction[name].is_a?(Symbol)
        return true if @restriction[name] == self.class.default

        false
      end

      def prohibit(*args)
        self.class.prohibit(*args)
      end

      protected

      def restriction_list_for_name(name)
        if @restriction.is_a? Regexp
          self.class.default
        elsif @restriction[name].nil?
          self.class.default
        else
          @restriction[name]
        end
      end
    end
  end
end
