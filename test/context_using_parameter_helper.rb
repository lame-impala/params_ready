require_relative '../lib/params_ready/builder'
module ContextUsingParameter
  def self.get_def
    ParamsReady::Builder.define_hash(:param) do
      add :value, :using_context do
        coerce do |value, context|
          next value unless context.marshal? :value

          inc = context[:inc]
          coerced = Integer(value)
          coerced + inc
        end

        format do |value, intent|
          dec = intent.data[:dec].unwrap
          output = value - dec
          output.to_s
        end
      end
    end
  end
end