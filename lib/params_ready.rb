require 'ruby2_keywords'
require 'arel'

require_relative 'params_ready/parameter/array_parameter'
require_relative 'params_ready/parameter/hash_parameter'
require_relative 'params_ready/parameter/hash_set_parameter'
require_relative 'params_ready/parameter/polymorph_parameter'
require_relative 'params_ready/parameter/tuple_parameter'
require_relative 'params_ready/parameter/value_parameter'

require_relative 'params_ready/value/custom'
require_relative 'params_ready/value/validator'

require_relative 'params_ready/input_context'
require_relative 'params_ready/output_parameters'
require_relative 'params_ready/parameter_definer'
require_relative 'params_ready/parameter_user'
require_relative 'params_ready/query_context'

require_relative 'params_ready/query/array_grouping'
require_relative 'params_ready/query/custom_predicate'
require_relative 'params_ready/query/exists_predicate'
require_relative 'params_ready/query/fixed_operator_predicate'
require_relative 'params_ready/query/nullness_predicate'
require_relative 'params_ready/query/polymorph_predicate'
require_relative 'params_ready/query/relation'
require_relative 'params_ready/query/variable_operator_predicate'


module ParamsReady
  VERSION = '0.0.6'.freeze

  def self.gem_version
    ::Gem::Version.new(VERSION)
  end
end
