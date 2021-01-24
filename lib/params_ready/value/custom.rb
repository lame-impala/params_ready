require_relative '../parameter/value_parameter'

module ParamsReady
  module Value
    class DowncaseStringCoder < StringCoder
      def self.coerce(value, context)
        string = super
        string.downcase
      end
    end

    Parameter::ValueParameterBuilder.register_coder :downcase_string, DowncaseStringCoder

    class FormattedDecimalCoder < DecimalCoder
      EU = /^(\d{1,3}( \d{3})+|\d+),\d{1,2}$/.freeze
      US = /^(\d{1,3}(,\d{3})+).\d{1,2}$/.freeze

      def self.coerce(value, context)
        value = if value.is_a? String
          stripped = value.strip
          if EU.match? stripped
            stripped.gsub(/[ ,]/, ' ' => '', ',' => '.')
          elsif US.match? stripped
            stripped.delete(',')
          else
            stripped
          end
        else
          value
        end
        super
      end
    end

    Parameter::ValueParameterBuilder.register_coder :formatted_decimal, FormattedDecimalCoder

    class CheckboxBooleanCoder < BooleanCoder
      def self.format(value, format)
        return value unless format.marshal? :boolean
        return value ? 'true' : nil
      end
    end

    Parameter::ValueParameterBuilder.register_coder :checkbox_boolean, CheckboxBooleanCoder

    class NonEmptyStringCoder < StringCoder
      def self.coerce(value, _)
        return Extensions::Undefined if value.nil? || value.empty?

        super
      end
    end

    Parameter::ValueParameterBuilder.register_coder :non_empty_string, NonEmptyStringCoder
  end
end