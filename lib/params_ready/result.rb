require_relative 'error'

module ParamsReady
  class AbstractReporter
    attr_reader :name

    def initialize(name)
      @name = name.to_s.freeze
    end

    def error!(err)
      report_error(nil, err)
    end

    def full_path(path)
      return [name] if path.nil? || path.empty?
      [name, *path]
    end

    def for_child(name)
      Reporter.new name, self
    end
  end

  class Result < AbstractReporter
    class Error < ParamsReadyError; end

    def initialize(name)
      super
      @errors = []
      @children = {}
    end

    def full_scope(scope)
      return name if scope.empty?

      "#{scope}.#{name}"
    end

    def errors(scope = '')
      scope = full_scope(scope)
      proper = @errors.empty? ? {} : { scope => @errors }
      @children.values.reduce(proper) do |result, child|
        result.merge(child.errors(scope))
      end
    end

    def report_error(path, err)
      raise ParamsReadyError, "Is not Error: #{err}" unless err.is_a? StandardError

      name, *path = path
      if name.nil?
        @errors << err
      else
        @children[name] ||= Result.new(name)
        @children[name].report_error(path, err)
      end
    end

    def ok?
      return false unless @errors.empty?

      @children.values.all? do |child|
        child.ok?
      end
    end

    def child_ok?(path)
      name, *path = path
      return ok? if name.nil?
      return true unless @children.key? name

      @children[name].child_ok?(path)
    end

    def error
      return nil if ok?

      Result::Error.new(error_messages(' -- '))
    end

    def error_messages(separator = "\n")
      errors.flat_map do |scope, errors|
        ["errors for #{scope}"] + errors.map { |err| err.message }
      end.join(separator)
    end
  end

  class Reporter < AbstractReporter
    attr_reader :name

    def initialize(name, parent)
      super name
      @parent = parent
    end

    def ok?
      child_ok?(nil)
    end

    def child_ok?(path)
      @parent.child_ok?(full_path(path))
    end

    def report_error(path, err)
      @parent.report_error(full_path(path), err)
    end
  end
end
