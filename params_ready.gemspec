require_relative 'lib/params_ready'

Gem::Specification.new do |s|
  s.name        = 'params_ready'
  s.version     = ParamsReady::VERSION
  s.licenses    = ['MIT']
  s.date        = '2020-10-07'
  s.homepage    = 'https://github.com/lame-impala/params_ready'
  s.summary     = 'Define controller interfaces in Rails'
  s.description = <<~DESC
    Create well defined controller interfaces. Sanitize, coerce and constrain 
    incoming parameters to safely populate data models, hold session state in URI variables 
    across different locations, build SQL queries, apply ordering and offset/keyset pagination.
  DESC
  s.authors     = ['Tomas Milsimer']
  s.email       = 'tomas.milsimer@protonmail.com'
  s.files       = %w[
    lib/arel/cte_name.rb

    lib/params_ready/extensions/class_reader_writer.rb
    lib/params_ready/extensions/collection.rb
    lib/params_ready/extensions/delegation.rb
    lib/params_ready/extensions/finalizer.rb
    lib/params_ready/extensions/freezer.rb
    lib/params_ready/extensions/hash.rb
    lib/params_ready/extensions/late_init.rb
    lib/params_ready/extensions/registry.rb
    lib/params_ready/extensions/undefined.rb

    lib/params_ready/helpers/arel_builder.rb
    lib/params_ready/helpers/conditional_block.rb
    lib/params_ready/helpers/find_in_hash.rb
    lib/params_ready/helpers/interface_definer.rb
    lib/params_ready/helpers/key_map.rb
    lib/params_ready/helpers/memo.rb
    lib/params_ready/helpers/options.rb
    lib/params_ready/helpers/parameter_definer_class_methods.rb
    lib/params_ready/helpers/parameter_storage_class_methods.rb
    lib/params_ready/helpers/parameter_user_class_methods.rb
    lib/params_ready/helpers/relation_builder_wrapper.rb
    lib/params_ready/helpers/rule.rb
    lib/params_ready/helpers/storage.rb
    lib/params_ready/helpers/usage_rule.rb

    lib/params_ready/marshaller/array_marshallers.rb
    lib/params_ready/marshaller/builder_module.rb
    lib/params_ready/marshaller/collection.rb
    lib/params_ready/marshaller/definition_module.rb
    lib/params_ready/marshaller/hash_marshallers.rb
    lib/params_ready/marshaller/hash_set_marshallers.rb
    lib/params_ready/marshaller/parameter_module.rb
    lib/params_ready/marshaller/polymorph_marshallers.rb
    lib/params_ready/marshaller/tuple_marshallers.rb

    lib/params_ready/pagination/abstract_pagination.rb
    lib/params_ready/pagination/cursor.rb
    lib/params_ready/pagination/direction.rb
    lib/params_ready/pagination/keyset_pagination.rb
    lib/params_ready/pagination/keysets.rb
    lib/params_ready/pagination/nulls.rb
    lib/params_ready/pagination/offset_pagination.rb
    lib/params_ready/pagination/tendency.rb

    lib/params_ready/parameter/abstract_hash_parameter.rb
    lib/params_ready/parameter/array_parameter.rb
    lib/params_ready/parameter/definition.rb
    lib/params_ready/parameter/hash_parameter.rb
    lib/params_ready/parameter/hash_set_parameter.rb
    lib/params_ready/parameter/parameter.rb
    lib/params_ready/parameter/polymorph_parameter.rb
    lib/params_ready/parameter/state.rb
    lib/params_ready/parameter/tuple_parameter.rb
    lib/params_ready/parameter/value_parameter.rb

    lib/params_ready/ordering/column.rb
    lib/params_ready/ordering/ordering.rb

    lib/params_ready/query/array_grouping.rb
    lib/params_ready/query/custom_predicate.rb
    lib/params_ready/query/exists_predicate.rb
    lib/params_ready/query/fixed_operator_predicate.rb
    lib/params_ready/query/grouping.rb
    lib/params_ready/query/join_clause.rb
    lib/params_ready/query/nullness_predicate.rb
    lib/params_ready/query/polymorph_predicate.rb
    lib/params_ready/query/predicate.rb
    lib/params_ready/query/predicate_operator.rb
    lib/params_ready/query/relation.rb
    lib/params_ready/query/structured_grouping.rb
    lib/params_ready/query/variable_operator_predicate.rb

    lib/params_ready/value/coder.rb
    lib/params_ready/value/constraint.rb
    lib/params_ready/value/custom.rb
    lib/params_ready/value/validator.rb

    lib/params_ready/builder.rb
    lib/params_ready/error.rb
    lib/params_ready/format.rb
    lib/params_ready/input_context.rb
    lib/params_ready/intent.rb
    lib/params_ready/output_parameters.rb
    lib/params_ready/parameter_definer.rb
    lib/params_ready/parameter_user.rb
    lib/params_ready/query_context.rb
    lib/params_ready/restriction.rb
    lib/params_ready/result.rb

    lib/params_ready.rb
  ]
  s.add_dependency 'ruby2_keywords', '~> 0'
  s.add_dependency 'activerecord', '~> 6'
  s.add_development_dependency 'byebug', '~> 11'
  s.add_development_dependency 'memory_profiler', '~> 0.9'
  s.add_development_dependency 'minitest-rg', '~> 5'
  s.add_development_dependency 'simplecov', '~> 0.20'
  s.add_development_dependency 'sqlite3', '~> 1'
end
