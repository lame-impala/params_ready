require 'simplecov'
SimpleCov.root "#{Dir.getwd}/"
SimpleCov.start do
    add_filter %r{^/test/}
end

require_relative 'examples/examples'

require_relative 'extensions/freezer_test'
require_relative 'extensions/class_reader_writer_test'
require_relative 'extensions/hash_test'

require_relative 'helpers/key_map_test'

require_relative 'marshaller/collection_test'
require_relative 'marshaller/tuple_marshallers_test'
require_relative 'marshaller/custom_marshallers'

require_relative 'ordering/ordering_test'

require_relative 'pagination/keyset_pagination_test'
require_relative 'pagination/cursor_builder_test'
require_relative 'pagination/keysets_test'
require_relative 'pagination/direction_test'
require_relative 'pagination/nulls_test'
require_relative 'pagination/offset_pagination_test'
require_relative 'pagination/tendency_test'

require_relative 'parameter/array_parameter_test'
require_relative 'parameter/hash_mapping_test'
require_relative 'parameter/hash_parameter_test'
require_relative 'parameter/hash_set_parameter_test'
require_relative 'parameter/inspect_test'
require_relative 'parameter/memo_test'
require_relative 'parameter/polymorph_parameter_test'
require_relative 'parameter/tuple_parameter_test'
require_relative 'parameter/value_parameter_test'
require_relative 'parameter/delegating_parameter_test'
require_relative 'parameter/rule_test'
require_relative 'parameter/state_test'

require_relative 'query/array_grouping_test'
require_relative 'query/keyset_pagination_relation_test'
require_relative 'query/custom_predicate_test'
require_relative 'query/exists_predicate_test'
require_relative 'query/fixed_operator_predicate_test'
require_relative 'query/inner_join_test'
require_relative 'query/join_test'
require_relative 'query/nullness_predicate_test'
require_relative 'query/outer_join_test'
require_relative 'query/polymorph_predicate_test'
require_relative 'query/selector_test'
require_relative 'query/structured_grouping_test'
require_relative 'query/relation_test'
require_relative 'query/variable_operator_predicate_test'

require_relative 'value/boolean_test'
require_relative 'value/constraint_test'
require_relative 'value/custom_test'
require_relative 'value/date_test'
require_relative 'value/datetime_test'
require_relative 'value/integer_test'
require_relative 'value/string_test'
require_relative 'value/value_test'
require_relative 'value/generic_test'

require_relative 'denylist_test'
require_relative 'format_test'
require_relative 'intent_test'
require_relative 'keyset_pagination_parameter_user_test'
require_relative 'output_parameters_test'
require_relative 'parameter_definer_test'
require_relative 'parameter_user_test'
require_relative 'restriction_test'
require_relative 'result_test'
require_relative 'set_with_context_test'

