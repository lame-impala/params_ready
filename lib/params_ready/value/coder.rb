require 'date'
require_relative '../error'
require_relative '../extensions/late_init'
require_relative '../extensions/finalizer'
require_relative '../extensions/class_reader_writer'

module ParamsReady
  module Value
    class Coder
      extend Extensions::ClassReaderWriter

      class_reader_writer :type_identifier
      type_identifier :value

      def self.value_class_name
        last = self.name.split("::").last
        last.remove('Coder')
      end

      def self.try_coerce(input, context)
        coerce input, context
      rescue => _error
        raise CoercionError.new(input, value_class_name)
      end

      def self.strict_default?
        true
      end
    end

    class GenericCoder
      extend Extensions::LateInit
      extend Extensions::Finalizer
      include Extensions::Finalizer::InstanceMethods

      def initialize(name)
        @name = name
        @coerce = nil
        @format = nil
        @type_identifier = nil
      end

      def strict_default?; true; end

      late_init(:coerce, getter: false)
      late_init(:format, getter: false)
      late_init(:type_identifier, obligatory: false)

      def value_class_name
        @name
      end

      def try_coerce(input, context)
        @coerce[input, context]
      rescue => _error
        raise CoercionError.new(input, @name)
      end

      def format(value, format)
        @format[value, format]
      end

      def finish
        super
        freeze
      end
    end
  
    class IntegerCoder < Coder
      type_identifier :number

      def self.coerce(input, _)
        return nil if input.nil? || input == ''
        Integer(input)
      end
  
      def self.format(value, format)
        value.to_s
      end
    end
  
    class DecimalCoder < Coder
      type_identifier :number

      def self.coerce(input, _)
        return nil if input.nil? || input == ''
        BigDecimal(input)
      end
  
      def self.format(value, format)
        value.to_s('F')
      end
    end
  
    class BooleanCoder < Coder
      type_identifier :boolean

      def self.coerce(input, _)
        return nil if input.nil? || input == ''
        return input if input.is_a?(TrueClass) || input.is_a?(FalseClass)
        str = input.to_s
        case str
        when 'true', 'TRUE', 't', 'T', '1'
          true
        when 'false', 'FALSE', 'f', 'F', '0'
          false
        else
          raise
        end
      end
  
      def self.format(value, format)
        value.to_s
      end
    end
  
    class StringCoder < Coder
      def self.coerce(input, _)
        input.to_s
      end
  
      def self.format(value, _)
        value
      end
    end
  
    class SymbolCoder < Coder
      type_identifier :symbol

      def self.coerce(input, _)
        input.to_sym
      end
  
      def self.format(value, format)
        value.to_s
      end
    end
  
    class DateCoder < Coder
      type_identifier :date

      def self.coerce(input, _)
        return nil if input.nil? || input == ''
        if input.is_a?(Numeric)
          Time.at(input).to_date
        elsif input.is_a?(String)
          Date.parse(input)
        elsif input.respond_to?(:to_date)
          input.to_date
        else
          raise ParamsReadyError, "Unimplemented for type #{input.class.name}"
        end
      end
  
      def self.format(value, format)
        value.to_s
      end
    end
  
    class DateTimeCoder < Coder
      type_identifier :date

      def self.coerce(input, _)
        return nil if input.nil? || input == ''
        if input.is_a?(Numeric)
          Time.at(input).to_datetime
        elsif input.is_a?(String)
          DateTime.parse(input)
        elsif input.respond_to?(:to_datetime)
          input.to_datetime
        else
          raise ParamsReadyError, "Unimplemented for type #{input.class.name}"
        end
      end
  
      def self.format(value, format)
        value.to_s
      end
    end
  end
end