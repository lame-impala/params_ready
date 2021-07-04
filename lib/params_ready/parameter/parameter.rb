require 'forwardable'
require_relative '../extensions/freezer'
require_relative '../error'
require_relative '../helpers/memo'
require_relative '../helpers/find_in_hash'

module ParamsReady
  module Parameter
    module FromHash
      def set_from_hash(hash, context: nil, validator: Result.new(name))
        if no_input?(context)
          populate(context, validator)
        else
          _, input = find_in_hash hash, context
          set_from_input(input, context, validator)
        end
      end
    end

    module ComplexParameter
      def update_child(value, path)
        child, child_name, child_path = child_for_update(path)
        changed, updated = child.update_if_applicable(value, child_path)

        if frozen? && !changed
          [false, self]
        else
          clone = updated_clone(child_name, updated)
          [true, clone]
        end
      end
    end

    module DelegatingParameter
      include ComplexParameter
      include FromHash

      def self.included(recipient)
        recipient.freeze_variable :data
      end

      def method_missing(name, *args)
        if @data.respond_to?(name)
          @data.send name, *args
        else
          super
        end
      end

      def respond_to_missing?(name, include_private = false)
        if @data.respond_to?(name, include_private)
          true
        else
          super
        end
      end

      def set_value(input, context = Format.instance(:backend), validator = nil)
        if self.match?(input)
          super input.unwrap, context, validator
        else
          super
        end
      end

      def hash
        [definition, data].hash
      end

      def ==(other)
        return false unless self.match?(other)
        data == other.data
      end

      alias_method :eql?, :==

      protected

      def child_for_update(path)
        [@data, nil, *path]
      end

      def updated_clone(_child_name, updated)
        clone = definition.create
        clone.instance_variable_set :@data, updated
        clone.freeze if frozen?
        clone
      end

      def set_from_input(input, context, validator)
        if self.match?(input)
          super input.unwrap, context, validator
        else
          super
        end
      end

      def populate_other(other)
        data.populate_other(other.data)
      end
    end

    class AbstractParameter
      attr_reader :definition
      extend Forwardable
      extend Extensions::Freezer
      include Extensions::Freezer::InstanceMethods
      include FromHash

      def_delegators :@definition, :name, :altn, :name_for_formatter

      def self.intent_for_children(method, &block)
        case method
        when :restriction
          raise ParamsReadyError, "Block unexpected for '#{method}' method" unless block.nil?
          define_method :intent_for_children do |intent|
            intent.for_children(self)
          end
        when :delegate
          define_method :intent_for_children do |intent|
            delegate_name, *others = self.instance_eval(&block)
            intent.delegate(self, delegate_name, *others)
          end
        when :pass
          raise ParamsReadyError, "Block unexpected for '#{method}' method" unless block.nil?
          define_method :intent_for_children do |intent|
            intent
          end
        else
          raise ParamsReadyError, "Unimplemented permission method: '#{method}'"
        end
      end

      intent_for_children :pass

      def initialize(definition, **options)
        raise ParamsReadyError, "Unexpected options: #{options}" unless options.empty?
        @definition = definition
      end

      def update_in(value, path)
        _, updated = update_if_applicable(value, path)
        updated
      end

      def update_if_applicable(value, path)
        if path.empty?
          update_self(value)
        elsif respond_to? :update_child
          update_child(value, path)
        else
          raise ParamsReadyError, "Expected path to be terminated in '#{name}'"
        end
      end

      def populate(context, validator)
        return if definition.populator.nil?

        definition.populator.call(context, self)
        validator
      rescue => error
        populator_error = PopulatorError.new(error)
        if validator.nil?
          raise populator_error
        else
          validator.error! populator_error
        end
        validator
      end

      def match?(other)
        return false unless other.instance_of?(self.class)
        definition == other.definition
      end

      def ==(other)
        return false unless self.match?(other)

        bare_value == other.bare_value
      rescue
        false
      end

      def to_hash(format = Format.instance(:backend), restriction: nil, data: nil)
        restriction ||= Restriction.blanket_permission
        intent = Intent.new(format, restriction, data: data)
        to_hash_if_eligible(intent) || {}
      end

      def inspect
        preserve = Format.instance(:inspect).preserve?(self)
        content = preserve ? inspect_content : '[FILTERED]'
        "#{self.class.name.split("::").last} #{self.name}: { #{content} }"
      end

      def dup
        clone = definition.create
        populate_other clone
        clone
      end

      protected

      def update_self(value)
        clone = definition.create
        clone.set_value value
        clone.freeze if frozen?
        [true, clone]
      end
    end

    class Parameter < AbstractParameter
      def_delegators :@definition,
                     :default, :optional?, :default_defined?, :constraints, :no_output?, :no_input?

      def initialize(definition)
        @value = Extensions::Undefined
        super definition
      end

      def set_value(input, context = Format.instance(:backend), validator = nil)
        if Extensions::Undefined.value_indefinite?(input)
          handle_indefinite_input(input, validator)
        elsif self.match? input
          @value = input.bare_value
        else
          begin
            value, validator = definition.try_canonicalize(input, context, validator)
            if validator.nil? || validator.ok?
              if Extensions::Undefined.value_indefinite?(value)
                handle_indefinite_input(value, validator)
              else
                @value = value
              end
            end
          rescue StandardError => e
            if validator.nil?
              raise e
            else
              validator.error! e
            end
          end
        end
        validator
      end

      def definite_default?
        default_defined? && !default.nil?
      end

      def nil_default?
        default_defined? && default.nil?
      end

      def is_definite?
        return true if @value != Extensions::Undefined && !@value.nil?
        return false if optional? && @value.nil?

        definite_default?
      end

      def is_default?
        return false unless default_defined?

        @value == Extensions::Undefined || @value == default
      end

      def is_nil?
        return false if is_definite?
        return true if optional?
        return true if nil_default?

        false
      end

      def is_undefined?
        @value == Extensions::Undefined && allows_undefined?
      end

      def allows_undefined?
        return true if optional?

        !default_defined?
      end

      def eligible_for_output?(intent)
        intent.preserve?(self)
      end

      def hash_key(format)
        format.hash_key(self)
      end

      def set_from_input(input, context, validator)
        preprocessed = definition.preprocess(input, context, validator)
        set_value preprocessed, context, validator
        definition.postprocess(self, context, validator)
        validator
      end

      def to_hash_if_eligible(intent = Intent.instance(:backend))
        return nil unless eligible_for_output? intent

        formatted = format_self_permitted(intent)
        wrap_output(formatted, intent)
      end

      def format_self_permitted(intent)
        intent = intent_for_children(intent)
        format(intent)
      end

      def format(intent)
        value = memo(intent)
        return value if value != Extensions::Undefined

        value = marshal(intent)
        memo!(value, intent)
        value
      end

      def memo(intent)
        return Extensions::Undefined if @memo.nil?

        @memo.cached_value(intent)
      end

      def memo!(value, intent)
        return if @memo.nil? || !frozen?

        @memo.cache_value(value, intent)
      end

      def wrap_output(output, intent)
        name_or_path = hash_key(intent)
        if name_or_path.is_a? Array
          *path, name = name_or_path
          result = {}
          Helpers::KeyMap::Mapping::Path.store(name, output, result, path)
          result
        else
          { name_or_path => output }
        end
      end

      def unwrap
        format(Intent.instance(:backend))
      end

      def unwrap_or(*args, &block)
        ensure_default_present!(*args, &block)

        if is_definite?
          begin
            unwrap
          rescue StandardError => _
            supply_default(*args, &block)
          end
        else
          supply_default(*args, &block)
        end
      end

      def find_in_hash(hash, context)
        Helpers::FindInHash.find_in_hash hash, hash_key(context)
      end

      def populate_other(other)
        raise ParamsReadyError, "Not a matching param: #{other.class.name}" unless match? other
        return other unless is_definite?

        value = bare_value
        other.populate_with(value)
        other
      end

      def inspect_content
        @value.inspect
      end

      freeze_variable :value

      def freeze
        if definition.memoize? and !frozen?
          @memo = Helpers::Memo.new(definition.memoize)
        end
        init_for_read true
        super
      end

      def hash
        [definition, @value].hash
      end

      alias_method :eql?, :==

      protected

      def handle_indefinite_input(input, validator)
        value_missing validator
        if default_defined?
          # if value_missing doesn't crash,
          # and the parameter is optional
          # it's safe to set to nil or Extensions::Undefined
          @value = Extensions::Undefined
        elsif optional?
          # Clear possible previous state,
          # will be set to default on read
          @value = input
        else
          raise ParamsReadyError, "Unexpected state for '#{name}' in #handle_indefinite_input" if validator.ok?
        end
      end

      def value_missing(validator = nil)
        if !nil_allowed?
          e = ValueMissingError.new self.name
          if validator
            validator.error!(e)
          else
            raise e
          end
        end
        validator
      end

      def nil_allowed?
        optional? || default_defined?
      end

      def bare_value
        init_for_read
        return @value if is_definite?

        value_missing
        nil
      end

      def ensure_default_present!(*args, &block)
        raise ParamsReadyError, 'Single default value expected' if args.length > 1
        raise ParamsReadyError, 'Supply either default or a block' if args.length == 0 && block.nil?
        warn 'WARNING: block supersedes default value' if args.length > 0 && block
      end

      def supply_default(*args, &block)
        if block.nil?
          args[0]
        else
          block.call
        end
      end

      def init_for_read(to_be_frozen = false)
        return unless @value == Extensions::Undefined
        return unless default_defined?

        @value = definition.fetch_default(duplicate: !to_be_frozen)
      end

      def init_for_write
        return if is_definite?

        if default_defined? && !default.nil?
          @value = definition.fetch_default
        else
          init_value
        end
      end

      def init_value
        # NOOP
      end
    end
  end
end