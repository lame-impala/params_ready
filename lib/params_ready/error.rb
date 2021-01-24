module ParamsReady
  class ParamsReadyError < RuntimeError; end

  class ErrorWrapper < ParamsReadyError
    attr_reader :error

    def initialize(error)
      @error = error
    end

    def message
      @error.message
    end
  end

  class PreprocessorError < ErrorWrapper; end
  class PostprocessorError < ErrorWrapper; end
  class PopulatorError < ErrorWrapper; end

  class ValueMissingError < StandardError
    def initialize(name)
      super "#{name}: value is nil"
    end
  end

  class CoercionError < RuntimeError
    def initialize(input, class_name)
      super "can't coerce '#{input}' into #{class_name}"
    end
  end
end
