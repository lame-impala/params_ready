# ParamsReady
## Define controller interfaces in Rails
Create well defined controller interfaces. Sanitize, coerce and constrain 
incoming parameters to safely populate data models, hold session state in URI variables 
across different locations, build SQL queries, apply ordering and offset/keyset pagination. 

## Basics
This library is concerned with the receiving part of the controller
interface, i.e. the set of parameters the controller would accept
for particular actions. Technically the interface is a tree
of `Parameter` objects of different types. Let’s first introduce 
these and show how they are defined and constructed. 

### Defining parameters
Each parameter type comes with a builder providing a bunch of convenience 
methods that together form a simple DSL for defining parameters. The result
of a build operation is a parameter definition encapsulating all settings 
for given parameter.

Following code uses builder to create a definition of an integer parameter named 
`:ranking` defaulting to zero:

```ruby
definition = Builder.define_integer :ranking do 
  default 0
end
```

There are equivalent methods in the form `"define_#{type_name}"` provided for
all parameter types that have been registered with the builder class, 
so that any of the following is possible: `Builder.define_string`, `Builder.define_struct`, etc. 

Predefined builders generally accept `:name` as the first positional 
argument and `:altn` (for  	‘alternative name’) as an optional keyword argument. 
When the latter is not supplied, `:altn` defaults to `:name`. For most builders
these are the only arguments they accept in the constructor, other options are
typically set by invoking a method from within the builder’s block. Common options
are:

- `#default` sets parameter default. Note that most value-like parameter types 
will not attempt to coerce the value passed in and the strict canonical 
type is required. This has no reason other than to prevent unexpected 
conversion bugs. A few built-in parameters relax on this policy, namely 
`Operator` and `GroupingOperator`, so it is possible to write `default :and`, 
passing in a symbol instead of an actual operator instance.
- `#optional` marks a parameter that can take on `nil` value in the elementary case. 
In specific contexts though, this flag has a slightly different meaning. 
See [Populate data models](#models) and [Array Parameter](#array-parameter)
for details.
- `#no_input` creates a parameter that doesn’t read from non-local input
(coming from the outside). An optional argument can be passed into the
method call to be used as the default value. Another way to assign a value
to the parameter is the `#populate` callback. A no-input parameter may be
used where a piece of information known at the current location needs to
be passed over elsewhere in a URI variable.
- `#no_output` prevents parameter from writing its value to non-local output (meaning
output sent to other location).
- `#local` option marks a parameter both as `no_input` and `no_output`. You can think of local 
parameters as instance variables on the parameter object with the advantage that they enjoy full 
library support for type coercion, duplication, freeze, update and more. As with the `#no_input` 
method, an optional default value is accepted.
- `#preprocess` sets a callback that allows to sanitize, alter or refuse value 
before parameter is instantiated from non-local input. 
The raw value is passed in along with context object and the parameter’s definition. 
The block can return the incoming value, some other value, or it can instantiate the parameter
from the definition and return that. If the input is considered unacceptable, 
an error can be raised.
- `#postprocess` callback is called just after parameter has been set from input. 
The block receives the parameter itself and a context object. 
- `#populate` is available only for parameters marked as `no_input`, so that they 
can be set in one sweep along with other parameters when reading from non-local input. A context 
object and the parameter object to operate on are passed in.
For some examples of these callbacks in use, check out the [Populate data models](#models) 
section of this document.

All of these method calls are evaluated within the context of the builder object. 
To reuse pieces of definition code you can wrap them in proc objects and invoke them later 
calling `#instance_eval` anywhere inside the block. There’s also a convenience 
method `#include` doing exactly that:

```ruby
local_zero = proc do
  local 0
end
definition = Builder.define_integer :ranking do
  include &local_zero
end
assert_equal 0, definition.default
assert_equal true, definition.instance_variable_get(:@no_input)
assert_equal true, definition.instance_variable_get(:@no_output)
```

The product of a builder is a parameter definition. It is frozen at the end of the 
process so it is safe to reuse it at different places. Parameters that have
been produced by the same definition match each other and can be set one from
another. Definition is used to create an instance of parameter:

```ruby
param = definition.create
assert_equal :ranking, param.name
```

More common way to instantiate parameter would be using the `#from_input` method, 
since it returns an object fully populated with data, guaranteed to be in
consistent state. It will accept any hash-like object as
input, including `ActionController::Parameters`. It also accepts a 
context object carrying information about formatting and possibly some 
additional data that may be needed by `#preprocess`, `#postprocess` and `#populate` 
callbacks.

The `#from_input` method returns a pair where the first element is a `Result` 
object and the second is the newly created parameter. Errors raised inside 
this method are caught and reported to the result. Client code should call `#ok?` 
on the result after the method returns to make sure it has received a consistent 
object to work with.

```ruby
context = InputContext.new(:frontend, data: {})
result, param = definition.from_input(1, context: context)
if result.ok?
  param.freeze
  assert_equal 1, param.unwrap
else 
  # Error handling here
end
```

It is a good idea to freeze the parameter right after it has been created. 
Both `#freeze` and `#dup` methods are implemented recursively 
on all built-in parameter types, which means structured parameters
are deeply frozen along with all their components. If you need 
to unfreeze a parameter, you can just invoke `#dup` on it and you
receive a completely independent unfrozen copy.

### Accessor methods
- Use `#unwrap` to retrieve value. This will raise if value hasn’t been set and 
the parameter neither has default defined nor it has been marked as optional. 
- There is a failsafe alternative method `#unwrap_or(default)`. Block can
be supplied instead of an argument to compute default value.

Other important methods common to all types of parameters include:
- `#is_undefined?` – this returns true unless parameter has been 
explicitly set (even to a `nil` value) or has a default (again, the default can be `nil`).
Specific case is a default-having parameter marked as optional. When set to `nil` value
explicitly, it will ignore the input and report it's state as undefined.
- `#is_nil?` returns true if parameter is defined and its value is `nil`, or is undefined
and it's default is `nil`.
- `#is_definite?` returns true unless parameter is undefined or its value is `nil`.

### Updating parameters
There are two ways to update parameter depending on whether it is frozen
or not.

To modify value in an unfrozen parameter use `#set_value`.  The method will accept value 
of correct type, of type coercible to the correct type, or a parameter object 
of matching type (one created using the same definition).

To obtain a modified version of a frozen parameter use `#update_in`. It 
accepts the new value as the first positional parameter and an array
that constitutes the path to the target within 
the parameter structure. If the path is empty, it is the receiver
object itself that is being updated.

Let’s see this in action. First we define a structured parameter,
initialize it from a hash and freeze it immediately. Then we update value
of one of the nested parameters:

```ruby
definition = Builder.define_struct :parameter do 
  add :struct, :inner do 
    add :integer, :a 
    add :integer, :b
  end
end

_, parameter = definition.from_input(inner: { a: 5, b: 10 })
parameter.freeze 

updated = parameter.update_in(15, [:inner, :b])
assert_equal 15, updated[:inner][:b].unwrap
```

When calling `#update_in` on a frozen parameter, only components actually
affected by the change are recreated in the process, the rest are shared 
across instances. This leads to less allocations and measurable improvement in 
performance as compared to unfrozen parameters.

## Basic types
### Value parameters
Value parameters can be roughly defined as those corresponding to one URI variable
represented by a single string. They may contain a Ruby primitive or a custom value
object given that it is able to unmarshal itself from string.
Only a couple of basic types are predefined as of current version but more can 
be added trivially with a few lines of code.

For the time being there are following predefined types: `:boolean`, `:integer`, `:decimal`, 
`:symbol`, `:string`, `:date`, and `:date_time`.

#### Custom coders
Little work is needed to define a custom value type. You have to supply
a coder able to coerce incoming value to the desired type. It is recommended
to register the coder with `ValueParameterBuilder` so that convenience methods
can be used for defining parameters of this type later on. Along with
the input value, the `#coerce` method receives a context object that may contain
information about how the incoming value is formatted. Throughout the library
this object is largely unused as all coercible formats are accepted, but it may
be useful where coercion involves some kind of transcoding. The coder also 
has to implement the `#format` method, even if it is a no-op. 
Here is an example of a simple coder definition:

```ruby
module ParamsReady
  module Value
    class DowncaseStringCoder < Coder
      def self.coerce(value, _context)
        string = value.to_s
        string.downcase
      end
    
      def self.format(value, _format)
        value
      end
    end

    Parameter::ValueParameterBuilder.register_coder :downcase_string, DowncaseStringCoder
  end
end
```

All built-in coders are implemented as static classes. Their coercion methods 
behave as pure functions and work only with the data passed in as arguments. Sometimes you 
may need to create a more flexible coder depending on some internal state. To achieve that, 
subclass `Coder::Instantiable` instead of `Coder`. Then you can pass initializer arguments 
for the coder instance into the builder:

```ruby
module ParamsReady
  module Value
    class EnumCoder < Coder::Instantiable
      def initialize(enum_class:)
        @enum_class = enum_class
      end
      
      def coerce(value, _context)
        @enum_class.instance(value)
      end
    
      def format(value, _format)
        value.to_s
      end
    end

    Parameter::ValueParameterBuilder.register_coder :enum, EnumCoder
  end
end

Builder.define_struct :struct do
  add :enum, :role_enum, enum_class: RoleEnum
end
```

There’s also a way to define a one-off coder within the definition block:

```ruby
Builder.define_value :custom do 
  coerce do |value, _context|
    Foo.new(value) 
  end

  format do |value, _format|
    value.to_s
  end
end
```

Or you can pass a ready-made coder instance into the builder factory method:

```ruby
class CustomCoder
  include Coercion 
  
  def coerce(value, _)
    # ...    
  end
  
  def format(value, _)
    # ...
  end
end

Builder.define_value :custom, CustomCoder.new
```

In case the coder is unable to handle the input there are several options for
what to do:
- it can throw an arbitrary error that will be wrapped into a `CoercionError` 
instance and passed down the line for further inspection. 
- If the value is unacceptable in given context but harmless otherwise and its occurrence
shouldn’t halt the process, the coder can return another value or `nil` instead
(the latter will only work if parameter is flagged as optional or has a default)

#### Constraints
Constraints may be imposed when defining a value parameter. A few types
of constraints are predefined by the library: `RangeConstraint`, `EnumConstraint` and
`OperatorConstraint`. Range constraint can be initialized with a `Range` object like so:

```ruby
constrained = Builder.define_integer :constrained do 
  constrain :range, (1..10)
end
```

Enum constraint works with `Array` and `Set`:

```ruby
constrained = Builder.define_string :constrained do 
  constrain :enum, %w[foo bar]
end
```

Operator constraint will accept any of the following
Ruby operators, passed in as symbols: `:=~, :<, :<=, :==, :>=, :>`
To constrain the value to be a non-negative integer we may do 
the following:

```ruby
non_negative = Builder.define_integer(:non_negative) do
  constrain :operator, :>=, 0
end.create
```

We specified the constraint by name in the `#constrain` method, but you can pass
in an instantiated constraint object instead.

Attempt at setting incorrect value raises `Value::Constraint::Error` as here:

```ruby
err = assert_raises do
  non_negative.set_value -5
end

assert err.is_a?(Value::Constraint::Error)
```

Sometimes you don’t want to raise if the value doesn’t pass checks and would prefer to
leave the parameter unset or use default. In such case you can pass `strategy: :undefine`
option to the `#constrain` call:

```ruby
d = Builder.define_integer(:param) do
  constrain :range, (1..5), strategy: :undefine
  default 3
end

r, p = d.from_input 6
assert r.ok?
assert_equal 3, p.unwrap
```

This strategy sets parameter to undefined whenever it runs into an unacceptable
value, which is fine if the parameter is optional or has default. Yet another 
strategy is `:clamp`, which works only with range constraint and `:<=`, `:>=` 
operators. It sets the parameter to the nearest acceptable value.

```ruby
d = Builder.define_integer(:param) do
  constrain :range, (1..5), strategy: :clamp
end

r, p = d.from_input 6
assert r.ok?
assert_equal 5, p.unwrap

r, p = d.from_input 0
assert r.ok?
assert_equal 1, p.unwrap
```

Note that `nil` is never subject to constraint, nullness is being checked by
different mechanism.


### Struct parameter
Struct parameter type is provided to represent structured parameters. It can host
parameters of any type so hierarchical structures of arbitrary depth 
can be defined. A struct parameter is defined like so:

```ruby
definition = Builder.define_struct :parameter do
  add :boolean, :checked do
    default true
  end
  add :string, :search do
    optional
  end
  add :integer, :detail

  optional
end
```

Here we have a struct parameter composed from one boolean parameter with default,
one optional string parameter and an integer parameter. The whole struct is also
optional. Builder names are used to define nested parameters, which is
only possible for builders registered with the `Builder` class. Alternatively, 
parameter definition may be passed into the `#add`  method. This is a possible 
way to reuse code written elsewhere:

```ruby
checked = Builder.define_boolean :checked do
  default true
end
search = Builder.define_string :search do 
  optional 
end

parameter = Builder.define_struct(:action) do
  add checked
  add search
end.create
```

Square brackets are used to access nested parameters. It is the parameter object, 
not its value, that is retrieved in this way. The `[]=` operator 
is defined as a shortcut though, so that value can be set directly.

```ruby
parameter[:search] = 'foo'
assert_equal 'foo', parameter[:search].unwrap
```

Struct parameter unwraps into a standard hash, with all nested parameters
unwrapped to their bare values:

```ruby
assert_equal({ checked: true, search: 'foo' }, parameter.unwrap)
```

It’s generally desirable to have default defined for struct parameters, 
but it may be tedious to write it out for complex structures.
There is a shortcut for struct parameters: just pass `:inferred` 
to the `#default` method and the parameter will construct 
the default for you. This will only succeed if all children either 
are optional or have default defined:

```ruby
parameter = Builder.define_struct :parameter do 
  add :integer, :int do 
    default 5
  end
  add :string, :str do
    optional
  end
  default :inferred
end.create 

assert_equal({ int: 5, str: nil }, parameter.unwrap)
```

### <a name="array-parameter">Array parameter</a>
Array parameter can hold an indefinite number of homogeneous values of both 
primitive and complex types.
In Rails, arrays received in the URI variables end up being represented as hashes 
with numeric keys. Rails models handle those hashes just fine but we might want to use
the array without feeding it through a model first. In these cases we can rely on `ArrayParameter`
to coerce incoming structure into the form of standard Ruby array. 
When working with hashes in place of arrays, we should prefer the structure 
where hash keys are actual indexes into the array and there is a `'cnt'` key 
to hold information about the source array length. 
This is convenient because we can omit array elements that either 
have a `nil` value or are set to their defaults from URI variables and 
still be able to reconstruct the array later.
Often though we have to cope with hashes representing arrays that do
not correspond to this canonical form. Then we can mark the array parameter
as `compact`. When converting hash into a compact array parameter,
indexes are disregarded so the result is an array of the same length 
as the original hash.

Array parameter is defined like this:

```ruby
post_ids = Builder.define_array :post_ids do
  prototype :integer, :post_id do
    default 5
  end
  default [1, 2, 3]
end.create
```

Array parameter can be set from an array of values that are all coercible to the
prototype: 

```ruby
post_ids.set_value [4, 5]
```

A subset of array methods is available on the `ArrayParameter`, namely `:<<, :length, 
:each, :map, :reduce`. To be able to work with the whole of the standard Ruby array 
interface, just call `:unwrap` on the parameter. This will return an array 
of bare values which it is safe to mutate without affecting the internal state 
of the parameter itself.

```ruby
assert_equal [4, 5], post_ids.unwrap
```

Array parameter can be set from a hash with integer keys containing a `'cnt'` key. Note
how defaults are filled in for missing values:

```ruby
post_ids.set_value('1' => 7, '3' => 10, 'cnt' => 5)
assert_equal [5, 7, 5, 10, 5], post_ids.unwrap
```

A compact array parameter can’t define default value for the 
prototype but can still define default for the parameter as a whole:

```ruby
definition = Builder.define_array :post_ids do
  prototype :integer, :post_id
  default [1, 2, 3]
  compact
end
```

The prototype of a compact array can be marked as optional, but then
the `nil` values are filtered out. Consider this example with a custom 
integer coder that returns `nil` when it receives zero value. A parameter 
defined this way ignores all incoming zeros:

```ruby
definition = Builder.define_array :nonzero_integers do
  prototype :value do
    coerce do |input, _|
      base = 10 if input.is_a? String
      integer = Integer(input, base)
      next if integer == 0

      integer
    end

    format do |value, _|
      value.to_s
    end
    optional
  end
  compact
end

_, parameter = definition.from_input [0, 1, 0, 2]
assert_equal [1, 2], parameter.unwrap
```   

### Enum set parameter
There’s a modification of StructParameter that unwraps into a `Set`. 
It may be particularly useful for building SQL ‘IN’ predicates
from data originating from checkboxes and similar form inputs. 
It is defined like this:

```ruby
definition = Builder.define_enum_set :set do 
  add :pending
  add :processing
  add :complete
end
_, parameter = definition.from_input(pending: true, processing: true, complete: false)
assert_equal [:pending, :processing].to_set, parameter.unwrap
```

This is the trivial case where values are identical to the keys. 
`EnumSetParameter` also allows to map each key to a specific value: 

```ruby
definition = Builder.define_enum_set :set do 
  add :pending, val: 0
  add :processing, val: 1
  add :complete, val: 2
end
_, parameter = definition.from_input(pending: true, processing: true, complete: false)
assert_equal [0, 1].to_set, parameter.unwrap
```

### Polymorph parameter
Polymorph parameter is a kind of a union type able to hold parameters of different 
types and names. Types must not necessarily be primitives, arbitrarily complex
struct or array parameters are allowed. A concept like this might not seem very practical 
at first since it can be replaced with struct parameters in most contexts, 
but it provides means to define heterogeneous arrays of parameters, which in turn 
are useful when composing dynamic SQL queries. 
Definition of a polymorph parameter needs to declare all acceptable
types: 

```ruby
polymorph_id = Builder.define_polymorph :polymorph_id do
  type :integer, :numeric_id do
    default 0
  end
  type :string, :literal_id
end.create
```

Once set to a definite value using a pair where the key is the type, the parameter 
will be converted to hash as follows:

```ruby
polymorph_id.set_value numeric_id: 1
assert_equal({ polymorph_id: { numeric_id: 1 }}, polymorph_id.to_hash)
```

Knowing the type, value can be retrieved using square brackets:

```ruby
type = polymorph_id.type
assert_equal(1, polymorph_id[type].unwrap)
```

### Tuple parameter
The following parameter type is used internally by the library but does
not seem extremely useful for common use cases. We mention it briefly here for completeness.

Tuple parameter allows storing more values in one URI variable, separated by
a special character. Client code using tuple parameters must guarantee
that separator character never appears in the data, otherwise parsing the value
will end up in an error. 

The library uses tuple parameter for offset pagination, which is defined somewhat like this: 

```ruby
definition = Builder.define_tuple :pagination do
  field :integer, :offset do
    constrain :operator, :>=, 0, strategy: :clamp
  end
  field :integer, :limit do 
    constrain :operator, :>=, 1, strategy: :clamp
  end
  marshal using: :string, separator: '-'
  default [0, 10]
end
```

Using this definition, the value would be marshalled as `pagination=0-10`

## Input / output
### Alternative names
When discussing builders we mentioned the possibility to define alternative 
name for a parameter. This feature was originally devised to reduce the length of URI strings, 
but it also comes handy in situations where the backend holds conversation with a foreign 
service that uses different naming convention.
Alternative name may be set in the builder constructor like so:

```ruby
definition = Builder.define_struct :struct, altn: :h do 
 add :string, :name, altn: :n
end
```

The two name sets are used in different contexts, depending on the
format option that is passed in when setting or retrieving data. 
To retrieve values from hash the parameter naturally needs to know what 
name set to use. By default the `#from_input` method works with `:frontend` 
format that uses alternative naming scheme.

```ruby
_, parameter = definition.from_input(n: 'FOO')
assert_equal({ name: 'FOO' }, parameter.unwrap)
``` 

If we wanted to populate a parameter from hash using standard names, we
can use predefined `:backend` format or pass in a custom format object:

```ruby
context = :backend # or Format.instance(:backend)
_, parameter = definition.from_input({ name: 'BAR' }, context: context)
assert_equal({ name: 'BAR' }, parameter.unwrap)
``` 

The `#unwrap` method uses standard naming scheme and there is no way to modify
this behaviour. For full control over how output is created, use `#for_output` 
method defined on `StructParameter`. It allows for format and restriction to be passed in
to express particular intent. It also has the helpful property 
that it never returns `nil` even in situations where `#unwrap` would; it returns
empty hash instead. 

```ruby
hash = parameter.for_output :frontend
assert_equal({ n: 'BAR' }, hash)
hash = parameter.for_output :backend
assert_equal({ name: 'BAR' }, hash)
``` 

### Remapping input structure
Alternative name doesn’t have to be a symbol, builder would also accept 
an array of symbols, which then serves as a path to the parameter value within the
input hash. Incoming parameters can be entirely remapped this way to fit the
structure of the parameter object. Mapping works on output in reverse so an
output hash formatted for frontend can be expected to match the original structure:

```ruby
definition = Builder.define_struct :parameter do
  add :string, :remapped, altn: [:path, :to, :string]
end

input = { path: { to: { string: 'FOO' }}}

_, parameter = definition.from_input(input)
assert_equal 'FOO', parameter[:remapped].unwrap
assert_equal input, parameter.to_hash(:frontend)
```

For struct parameters there exists yet another method to remap input structure,
independent of naming schemes. It transforms the input hash following 
a predefined mapping into an entirely new hash that is passed to the next stage, and likewise
it maps the output hash back to the original structure after it has been populated.
To define such mapping, we can call the `#map` method anywhere within 
the hash parameter definition block. It expects a key-value pair as argument, 
both key and value being arrays representing the path within the input and result hash 
respectively. The last element of either one of the arrays is a list of keys 
to copy from the input to the result and vice versa.

```ruby
definition = Builder.define_struct :parameter do
  add :string, :foo
  add :string, :bar
  add :integer, :first
  add :integer, :second


  map [:strings, [:Foo, :Bar]] => [[:foo, :bar]]
  map [:integers, [:First, :Second]] => [[:first, :second]]
end

input = { strings: { Foo: 'FOO', Bar: 'BAR' }, integers: { First: 1, Second: 2 }}

_, parameter = definition.from_input(input, context: :json)
assert_equal 'FOO', parameter[:foo].unwrap
assert_equal 'BAR', parameter[:bar].unwrap
assert_equal 1, parameter[:first].unwrap
assert_equal 2, parameter[:second].unwrap
assert_equal input, parameter.to_hash(:json)
```

Both methods to define mapping presented here are equally powerful but they are different in two
important aspects. When using the `#map` method, we need to define mapping for 
all of the children of the struct parameter, even for those where no remapping actually
happens, otherwise these children won’t receive no data at all. Also, of all formats 
predefined in this library, the `#map` method only works with `:json`. On the
other hand, the `#map` method seems to produce somewhat clearer code if the
hash structure is very complex.

### Minification
The output format designed to be encoded into URI variables omits 
undefined, `nil` and default values from output to reduce length 
of URI strings and prevent from unnecessary visual clutter in 
the address bar of the browser. Parameters marked as `no_output` are omitted too, 
but for different purpose – preventing secrets from leaking to the frontend.
The behaviour of no-output parameters is controlled 
by different flag on the format object. 
We can see minification in action when we invoke `#for_output` with `:frontend` 
formatting on a struct parameter containing default, optional and no-output children:

```ruby
definition = Builder.define_struct :parameter do
  add :string, :default_parameter do
    default 'FOO'
  end
  add :string, :optional_parameter do
    optional
  end
  add :string, :obligatory_parameter
  add :string, :no_output_parameter do
    no_output
  end
end

parameter = definition.create
parameter[:obligatory_parameter] = 'BAR'
parameter[:no_output_parameter] = 'BAX'

expected = { obligatory_parameter: 'BAR' }
assert_equal expected, parameter.for_output(Format.instance(:frontend))
_, from_input = definition.from_input({ obligatory_parameter: 'BAR', no_output_parameter: 'BAX' })
assert_equal parameter, from_input
```

On the last two lines of this snippet we see the parameter 
being successfully recreated from the minified input.

### Format
We’ve already seen `Format` in use and now we’ll take a look into how it is constructed
and what are implications of different flags both when processing input and
preparing hash for output.

Format is a simple Ruby object with a handful of instance variables: 
`@marshal`, `@naming_scheme`, `@remap`, `@omit` and `@local`. There is also an
optional property `@name` but it is not widely used throughout the library
as of current version. It might be used in the future for some fine-tuning of 
formatting behaviour. 

- `@naming_scheme` is used to determine what set of keys to use in input and
output operations. It can be one of `:standard` and `:alternative`.
- `@remap` determines whether key maps to remap the input
and output hash structure will be used. 
- `@omit` enumerates cases that will be omitted from the output. It is an array 
of options that may include `:undefined`, `:nil` and `:default`. 
Particular combinations of these settings are useful in different contexts. 
- `@local` carries information about the source or target of the data. If set to
`true`, location is considered trusted, with the particular effect that parameters
marked as local will read the input as any standard parameter and local and no-output parameters
will write to the output. Also `#preprocess`, `#populate` and `#postprocess`
methods will be bypassed on assumption data coming from the backend are complete 
and consistent and don’t need to be transformed during processing.
- `@marshal` flag determines whether or not to transform values 
to a representation specific for string output. It doesn’t necessarily mean 
that the value will be converted directly to string; in the case of `ArrayParameter`, 
the value is transformed into a hash with numeric keys and a `'cnt'` key, 
that is expected to be serialized to string by the Rails' `#to_query` method further on. 
On the other hand, value types like `Date` are marshalled into string
directly. Marshal flag accepts the following values:
`:all`, `:none`, `only: [:type_name, ...]`, `except: [:type_name, ...]`. 
Parameters use type identifiers like `:array, :tuple, ...` to determine whether 
to marshal their values. Besides that, all predefined value coders have their 
respective type identifiers. Currently in use are `:number` for Integer and BigDecimal, 
`:date` for Date and DateTime, also `:boolean` and `:symbol`. Newly defined custom types can 
specify their own type identifier or fallback to the default, which is `:value`.

To marshal only `DateParameter` and `DateTimeParameter` and nothing else you could 
initialize `Format` object with following flags: 

```ruby
new_format = Format.new(
  marshal: { only: [:date] }, 
  naming_scheme: :standard, 
  remap: false, 
  omit: %i[undefined nil default], 
  local: false
)
```

You can create a globally accessible definition for a custom format.
This gives you the option to pass symbolic identifiers into methods 
like `#from_input` and `#for_output` instead of a format object:

```ruby
Format.define(:only_date, new_format)
```

First argument is the identifier of the new format (not to be confused with the `@name` 
instance variable). Format object created this way can be obtained later 
using `Format.instance(:only_date)`. It is also possible to redefine existing formats
this way, such as `:frontend`, `:json`, `:backend`, `:create` and `:update`.

### Restriction
Sometimes we need to decide dynamically what particular parameters to include in or omit from output. 
The library provides the concept of restriction to do that. The `Restriction` class 
defines two factories, `::permit` and `::prohibit` that expect an array of 
symbols representing parameter names and returns an instance of restriction object that
can be passed to the `#for_output` method and the likes.   
Each parameter in the list is either permitted or prohibited as a whole. If you need more
granularity, you can pass in name of the parent parameter followed by another list, permitting or 
prohibiting the children parameters, possibly going on to arbitrary depth. 
Let’s see an illustration of this in code:

```ruby
definition = Builder.define_struct :parameter do
  add :string, :allowed
  add :integer, :disallowed
  add :struct, :allowed_as_a_whole do
    add :integer, :allowed_by_inclusion
  end
  add :struct, :partially_allowed do
    add :integer, :allowed
    add :integer, :disallowed
  end
end

input = {
  allowed: 'FOO',
  disallowed: 5,
  allowed_as_a_whole: {
    allowed_by_inclusion: 8
  },
  partially_allowed: {
    allowed: 10,
    disallowed: 13
  }
}

_, parameter = definition.from_input(input)
```

We have defined a struct parameter containing one simple and two complex 
parameters as children. We’ll show both permission and prohibition approaches 
to achieve the same goal:

```ruby
format = Format.instance :backend
expected = {
  allowed: 'FOO',
  allowed_as_a_whole: {
    allowed_by_inclusion: 8
  },
  partially_allowed: {
    allowed: 10
  }
}

restriction = Restriction.permit :allowed, :allowed_as_a_whole, partially_allowed: [:allowed]
output = parameter.for_output(format, restriction: restriction)
assert_equal expected, output

restriction = Restriction.prohibit :disallowed, partially_allowed: [:disallowed]
output = parameter.for_output(format, restriction: restriction)
assert_equal expected, output
```

## Putting parameters to work
### <a name="models">Populate data models</a>
The design of this library is based on the premise that
it is the responsibility of the controller interface 
to deliver correct and consistent data to the models. 
Models validate adherence of data to business rules, but 
whenever it is possible to assess data correctness without knowing about 
the business logic, it should be done early on, ideally at the 
entrance point into the application.
 
In this section we’ll show some advanced ways to prepare 
data to be passed over to the models. First we need to get familiar 
with the `:create` and `:update` formats constructed to 
meet model requirements. Here is are the definitions:

```ruby
Format.new(marshal: :none, omit: [], naming_scheme: :standard, remap: false, local: true, name: :create)
Format.new(marshal: :none, omit: %i(undefined), naming_scheme: :standard, remap: false, local: true, name: :update)
```

Both formats use standard naming scheme and declare their target as local.
The only difference is that the `:update` format omits undefined parameters 
from output. Undefined parameters are those marked as optional that haven’t 
been set to any value (even `nil`) during the initialization, either because 
the value was not present in the data or it has been rejected in the 
`#preprocess` callback.

We typically want to use the same parameter set for both create and update actions on 
models. If we define some defaults for parameters that are not guaranteed to be present
in the input data (in situations where some inputs are disabled for particular users), 
we might want to use those defaults on create but not on update, where the 
model presumably has all attributes already set to correct values. To prevent current 
attribute values to be overwritten on update, we can mark default having parameters as optional 
so that they are considered undefined if the value is missing from the input. 

Consider this struct parameter holding attributes for a model:

```ruby
definition = Builder.define_struct :model do
  add :string, :name
  add :integer, :role do
    default 2
    optional
  end
  add :integer, :ranking do
    optional
  end
  add :integer, :owner_id do
    default nil
  end
end
```

The only required parameter is `:name`, other have either default defined or 
are optional (or both). We can expect all attributes to be set on create even if the
input is incomplete:

```ruby
_, p = definition.from_input(name: 'Joe')
assert_equal( { name: 'Joe', role: 2, ranking: nil, owner_id: nil }, p.for_model(:create))
```

On update, the parameter will nonetheless yield different result, omitting optional attributes:

```ruby
_, p = get_user_def.from_input(name: 'Joe')
assert_equal( { name: 'Joe', owner_id: nil }, p.for_model(:update))
```

To illustrate the `#populate` callback, we'll modify the above example. The `:owner_id`
attribute is no more read from input but is provided by some authority via the context.
Also, instead of providing default, we mark it here as optional to prevent attribute value 
to be overwritten to `nil` if user id is missing:

```ruby
Builder.define_struct :model do
  add :string, :name
  add :integer, :owner_id do
    local; optional
    populate do |context, parameter|
      next if context[:user_id].nil?

      parameter.set_value context[:user_id]
    end
  end
end

context = InputContext.new(:frontend, { user_id: 5 })
_, p = definition.from_input({ name: 'Foo' }, context: context)
assert_equal({ name: 'Foo', owner_id: 5}, p.for_model(:update))
```

In the first case the value of the local parameter has been explicitly
set and it subsequently appears in the output hash. If the user id
is not found in the context, the parameter value is never set and it is excluded
from output:

```ruby
context = InputContext.new(:frontend, {})
_, p = definition.from_input({ name: 'Foo' }, context: context)
assert_equal({ name: 'Foo'}, p.for_model(:update))
```

Another example shows how data can be transformed in the `#preprocess` callback
into a form the model expects. Suppose we have a text input
allowing strings delimited by either a comma or a semicolon and we want to transform 
that into an array, while omitting empty strings: 

```ruby
definition = Builder.define_struct :model do
  add :array, :to do
    prototype :string

    preprocess do |input, _context, _definition|
      next [] if input.nil?
      input.split(/[,;]/).map(&:strip).reject(&:empty?)
    end
  end
  add :string, :from
end

_, p = definition.from_input({ to: 'a@ex.com; b@ex.com, c@ex.com, ', from: 'd@ex.com' })
assert_equal({ to: %w[a@ex.com b@ex.com c@ex.com], from: 'd@ex.com' }, p.for_model(:create))
```

In the last example we use a `#postprocess` block to alter the value of a parameter
after it has been constructed:

```ruby
definition = Builder.define_struct :model do
  add :integer, :lower
  add :integer, :higher

  postprocess do |parameter, _context|
    lower = parameter[:lower].unwrap
    higher = parameter[:higher].unwrap
    return if lower < higher

    parameter[:higher] = lower
    parameter[:lower] = higher
  end
end

_, p = definition.from_input({ lower: 11, higher: 6 })
assert_equal({ lower: 6, higher: 11 }, p.for_model(:create))
``` 

### <a name='uri_variables'>URI variables</a>
Often we need to transfer data via URI variables to another 
location – particularly information about filtering and pagination
or some other presentational aspects. We’ll use a very simplified example to
give a hint at how the library can help with this task. Later on we’ll 
show more complete solution. 

Let’s assume we have a paginated index of users searchable by name, and for each
user there is an index of posts, searchable by subject. We want to 
be able to paginate both indexes, while a jump to other page within
posts index should maintain options (search and pagination) for both users index and 
posts index. A bare-bones definition could look like this:

```ruby
definition = Builder.define_struct :parameter do
  add :struct, :users do
    add(:string, :name_match){ optional }
    add(:integer, :offset){ default 0 }
  end

  add :struct, :posts do
    add(:integer, :user_id){ optional }
    add(:string, :subject_match){ optional }
    add(:integer, :offset){ default 0 }
  end
end
```

Now let’s simulate a situation where the user is currently viewing the posts index, 
looking for a post with subject containing the word ‘Question’. The search string ‘John’ 
and offset of 20 arrived from the previous location, the users index, and are captured
and held in the parameter object to make it possible for the user to return at any point and
continue searching there. 

```ruby
_, parameter = definition.from_input(
  users: { name_match: 'John', offset: 20 },
  posts: { user_id: 11, subject_match: 'Question', offset: 30 }
)
parameter.freeze
```

A jump to the next page of the posts index can be performed using `#update_in`. 
The result of this call is expected to be encoded into URI variables later,
so we’ll use the `#for_frontend` to create the output hash. It is a convenience 
method that internally calls `#for_output` with `:frontend` formatting: 

```ruby
next_page = parameter.update_in(40, [:posts, :offset])
next_page_variables = {
  users: { name_match: 'John', offset: '20' },
  posts: { user_id: '11', subject_match: 'Question', offset: '40' }
}
assert_equal next_page_variables, next_page.for_frontend
```

To obtain URI variables for a back link to the users index, we need to 
keep only parameters related to that page, so we drop post related parameters 
using a restriction:

```ruby
back_link_to_users_variables = {
  users: { name_match: 'John', offset: '20' }
}
restriction = Restriction.permit(:users)
assert_equal back_link_to_users_variables, parameter.for_frontend(restriction: restriction)
```

In the [closing section](#integration) of this document we will present a comprehensive
solution to this problem using built-in features of the `Relation` class such as predicate 
parameters, pagination and ordering.

### Form tags
If you want to use parameters in html forms directly, without passing them through
a model, you may need to retrieve names and ids of form elements from the
parameter object. There is a decorator class called `OutputParameters` to 
provide those values:

```ruby
definition = Builder.define_struct :complex, altn: :cpx do
  add :string, :string_parameter, altn: :sp
  add :array, :array_parameter, altn: :ap do
    prototype :integer
  end
end.create

_, parameter = definition.from_input(sp: 'FOO', ap: [1, 2])

output_parameters = OutputParameters.new parameter.freeze, :frontend

assert_equal 'cpx', output_parameters.scoped_name
assert_equal 'cpx', output_parameters.scoped_id
assert_equal 'cpx[sp]', output_parameters[:string_parameter].scoped_name
assert_equal 'cpx_sp', output_parameters[:string_parameter].scoped_id
assert_equal 'cpx[ap][0]', output_parameters[:array_parameter][0].scoped_name
assert_equal 'cpx_ap_0', output_parameters[:array_parameter][0].scoped_id
assert_equal 'cpx[ap][cnt]', output_parameters[:array_parameter][:cnt].scoped_name
assert_equal 'cpx_ap_cnt', output_parameters[:array_parameter][:cnt].scoped_id
```

The `OutputParameters` initializer expects the parameter passed in to be frozen. 
Note that along with the parameter we are passing in a format identifier. 
The third possible argument could be a restriction. Both will be used throughout 
the lifetime of the decorator instance in methods that expect either format or 
restriction as arguments. This means we can call `#for_output`, `#build_select`, 
`#build_relation` and `#perform_count` on the `OutputParameters` object without 
passing in format or restriction explicitly.

Following line of code shows how we would use output parameters to generate form inputs. We call `#format` 
method instead of `#unwrap` since it respects pre-selected formatting while `#unwrap` always
uses `:backend` formatting.

```erb
<%= text_field_tag @prms[:users][:name_match].scoped_name, @prms[:users][:name_match].format %>
```

When there’s an array among your parameters, you can call `:cnt` on it 
to get the form label and id for count. The object you receive is not a real a parameter 
defined on the array; it is a wrapper for the `length` property created ad hoc 
just for this purpose. You’ll typically inject the count into the form as a hidden field:

```erb
<%= hidden_field_tag("#{@prms[:users][:filters][:array][:cnt].scoped_name}", @prms[:users][:filters][:array][:cnt].unwrap) %>
```

To extract multiple values from the parameter object in a form suitable to render into 
hidden fields, use `#flat_pairs`:

```ruby
exp = [["cpx[sp]", "FOO"], ["cpx[ap][0]", "1"], ["cpx[ap][1]", "2"], ["cpx[ap][cnt]", "2"]]
assert_equal exp, output_parameters.flat_pairs
```

## Building SQL
There is a category of parameters called ‘predicates’ that are designed
to form SQL clauses. Predicates are grouped on an object named `Relation`
that takes care to deliver data to them and decides which ones
are relevant for the particular query. There’s no automagic involved 
in the process, the library makes no attempt at guessing table names, 
column names or primary keys, everything must be explicitly defined.

For now a handful of basic predicate types are defined but the library
is open to extending the list with either generic or specific
custom predicates. These are the built-in predicate types:
- fixed operator predicate, where the operator is defined statically and only value
is conveyed via parameter,
- nullness predicate
- variable operator predicate, where both value and operator is passed over as a parameter,
- exists predicate,
- polymorph predicate, a union of arbitrary predicate types.

There are also `StructuredGrouping` and `ArrayGrouping` classes to combine predicates 
together.

Before introducing individual predicate types, it’s worthwhile to have a look at the 
relation parameter inside of which predicates live and come to action.  

### Relation
All predicates, simple and complex, are able to produce snippets of SQL based on the
data they receive. That in itself wouldn’t be terribly useful but there’s the `Relation` 
class that holds individual predicates together and is capable of constructing entire SQL 
queries from them. 

We’ll take a relatively complex relation to showcase some of the features that
will be described later in more detail. Suppose we want to filter users on their role,
profile name and a variable number of other conditions concerning the type of subscription
users have or don’t have and the category of posts they have written. The definition 
would look like this:

```ruby
definition = Builder.define_relation :users do
  model User                                                          #1
  operator { local :and }                                             #2
  end
  join_table Profile.arel_table, :outer do                            #3
    on(:user_id).eq(:id)
  end
  variable_operator_predicate :role_variable_operator, attr: :role do #4
    operators :equal, :greater_than_or_equal, :less_than_or_equal
    type :value, :integer
    optional
  end
  fixed_operator_predicate :name_like, attr: :name do                 #5
    arel_table Profile.arel_table
    operator :like
    type :value, :string
    optional
  end
  custom_predicate :active_custom_predicate do                        #6
    type :struct do
      add(:integer, :days_ago) { default 1 }
      add(:boolean, :checked) { optional }
      default :inferred
    end

    to_query do |table, context|
      next nil unless self[:checked].unwrap

      date = context[:date] - self[:days_ago].unwrap
      table[:last_access].gteq(date)
    end
  end
  array_grouping_predicate :having_subscriptions do                   #7
    operator do
      default :and
    end
    prototype :polymorph_predicate, :polymorph do                     #8
      type :exists_predicate, :subscription_category_exists do        #9
        arel_table Subscription.arel_table
        related { on(:id).eq(:user_id) }
        fixed_operator_predicate :category_equal, attr: :category do  #10
          operator :equal
          type :value, :string
        end
      end
      type :exists_predicate, :subscription_channel_exists do         #11
        arel_table Subscription.arel_table
        related { on(:id).eq(:user_id) }
        fixed_operator_predicate :channel_equal, attr: :channel do
          operator :equal
          type :value, :integer
        end
      end
    end
    optional
  end
  paginate 100, 500                                                   #12
  order do                                                            #13
    column :created_at, :desc
    column :email, :asc
    column :name, :asc, arel_table: Profile.arel_table, nulls: :last
    column :ranking, :asc, arel_table: :none
    default [:created_at, :desc], [:email, :asc]
  end
end
```

That is one deliberately complex definition. Let’s break it down to pieces.

1) declares which model we use as the recipient for the data. If we don’t 
have this information at the time parameter is defined, the model class
can be passed into the `#build_relation` method later. Also, it doesn’t 
necessarily have to be an `ActiveRecord` model, a scope is acceptable too.
2) sets the operator to be used to combine predicates together. It is declared
as local here with default `:and`. Later on we’ll see a non-local operator 
that can be set from the input.
3) joins against `Profile`, where the `name` column is to be found.
4) defines a predicate to filter users on role. It is a variable operator
predicate with `=`, `<=` and `>=` operators explicitly allowed.
5) defines a predicate to filter users on name. It is a fixed operator
predicate using `:like` operator.
6) defines a custom predicate. Note that it uses some external data
retrieved from the context.
7) defines an array grouping that can hold arbitrary number of predicates.
8) here comes the variable operator predicate to use within this grouping
9) what’s more interesting, this array predicate allows for polymorph predicates, namely
10) exists predicate querying for user having certain category of subscription
11) and exists predicate querying for user having subscription to a certain channel
12) declares use of pagination (offset method by default) and sets the default limit. 
The second argument is an optional max limit. The constraint enforcing the limit 
uses `:clamp` strategy so if higher value is submitted, it is silently replaced 
by the maximum.
13) allows ordering on certain columns and defines default ordering

Now if we initialize this relation with some values we can make it build 
the query:

```ruby
params = {
  role_variable_operator: { operator: :equal, value: 1 },
  name_like: 'Ben',
  active_custom_predicate: {
    checked: true,
    days_ago: 5
  },
  having_subscriptions: {
    array: [
      { subscription_category_exists: { category_equal: 'vip' }},
      { subscription_channel_exists: { channel_equal: 1 }}
    ],
    operator: :or
  },
  ordering: [[:name, :asc], [:email, :asc], [:ranking, :desc]]
}
_, relation = definition.from_input(params, context: Format.instance(:backend))
date = Date.parse('2020-05-23')
context = QueryContext.new(Restriction.blanket_permission, { date: date })
query = relation.build_select(context: context)
```

The call to `#build_select` results in SQL clause similar to this 
(depending on the DB adapter in use):

```sql
SELECT * FROM users 
LEFT OUTER JOIN profiles ON users.user_id = profiles.id 
WHERE (
  users.role = 1 
  AND profiles.name LIKE '%Ben%' 
  AND users.last_access >= '2020-05-18' 
  AND (EXISTS (
    SELECT * FROM subscriptions 
    WHERE (subscriptions.category = 'vip') 
    AND (users.id = subscriptions.user_id) LIMIT 1)
  OR EXISTS (
    SELECT * FROM subscriptions 
    WHERE (subscriptions.channel = 1) 
    AND (users.id = subscriptions.user_id) LIMIT 1)
  )
)
ORDER BY CASE WHEN profiles.name IS NULL THEN 1 ELSE 0 END, 
         profiles.name ASC, 
         users.email ASC, ranking DESC 
LIMIT 100 OFFSET 0
``` 

For demonstration purposes we used `#build_select` method that returns an Arel object 
but typically the `#build_relation` method will be used to create an `ActiveRecord` relation. 
Besides that there is the `#perform_count` method that takes the same arguments as `#build_relation`
but outputs a number of records in the database meeting given conditions.

Here we see an invocation of `#build_relation` with some more options it accepts:

```ruby
restriction = Restriction.permit(:name_like, { ordering: [:name] })
result = relation.build_relation(scope: User.active, include: [:posts], context: restriction)
```

If scope is passed in, it will be used in preference to the model class set in the 
definition. We can also send in names of associations to preload and a restriction 
to allow or disallow particular predicates in given context.

The SQL query listed below is based on the same definition and input as
before but we use a restriction to limit which predicates and ordering clauses 
will participate in the query. Possible purpose of this could be to prevent 
users from inferring sensitive information using filtering and ordering on 
columns not visible to them.

```ruby
context = QueryContext.new(Restriction.permit(:name_like, ordering: [:name]))
query = relation.build_select(context: context)

exp = <<~SQL
  SELECT * FROM users 
  LEFT OUTER JOIN profiles ON users.user_id = profiles.id 
  WHERE (profiles.name LIKE '%Ben%')
  ORDER BY CASE WHEN profiles.name IS NULL THEN 1 ELSE 0 END, 
           profiles.name ASC 
  LIMIT 100 OFFSET 0
SQL
assert_equal exp.unformat, query.to_sql.unquote
```

### Fixed operator predicate 
The simplest of predicate types requires just an operator and value type
to be defined. In every respect it behaves just like a value-like parameter so
`:optional`, `:default` and other flags can be specified directly on it (with identical
meaning they can be specified on the type itself).

```ruby
definition = Query::FixedOperatorPredicateBuilder.instance(:role_equal, attr: :role).include do
  operator :equal
  type(:value, :integer)
  default 0
  arel_table User.arel_table
end.build

_, p = definition.from_input(32)

exp = "users.role = 32"
assert_equal exp, p.to_query(User.arel_table).to_sql.unquote
```

The builder accepts an extra argument along with the usual ones: `:attr`.
It is needed where the attribute name is different from the parameter
name (parameter names must be unique within the enclosing grouping).

The type can be any value-like parameter while possible operators are: `:equal`, 
`:not_equal`, `:like`, `:not_like`, `:greater_than`, `:less_than`, `:greater_than_or_equal`, 
`:less_than_or_equal`. It is possible to extend this catalog and add whatever operator
is supported by Arel.

We have defined Arel table on the parameter but this is optional. If we don’t specify one,
the base table of the enclosing relation or grouping will be used. Sometimes we don’t 
want to use any table at all, particularly with computed columns. In such cases we call 
`arel_table :none` instead and the bare attribute name will appear in the query.

This works fine for queries where the column is aliased in
the select list. But in some situations it is undesirable or even impossible
to have a selector for the computed column in the select list, as is the case of 
count queries or queries using keyset pagination. Then we need to pass an expression 
into the definition like so:

```ruby
definition = Query::FixedOperatorPredicateBuilder.instance(:activity_equal).include do
  operator :equal
  type(:value, :integer)
  default 0
  attribute name: :activity, expression: '(SELECT count(id) FROM activities WHERE activities.user_id = users.id)'
  arel_table :none
end.build
```

It is also possible to build the expression dynamically in a proc as shows the following, admittedly
somewhat stretched example:

```ruby
definition = Query::FixedOperatorPredicateBuilder.instance(:aggregate_equal).include do
  operator :equal
  type(:value, :integer)
  default 0
  attribute name: :aggregate, expression: proc { |_table, context|
    "(SELECT count(id) FROM #{context[:table_name]} WHERE #{context[:table_name]}.user_id = users.id)"
  }
  arel_table :none
end.build

_, p = definition.from_input(32)
exp = "(SELECT count(id) FROM activities WHERE activities.user_id = users.id) = 32"
context = QueryContext.new(Restriction.blanket_permission, { table_name: :activities })

assert_equal exp, p.to_query(User.arel_table, context: context).to_sql.unquote
```

Among operators allowed for the fixed operator predicate, `:in` and `:not_in` are special in that 
the type must be a collection (either `:array` or `:enum_set`). In all other aspects they work 
pretty much the same as the rest:

```ruby
role_in = FixedOperatorPredicateBuilder.build :role do
  operator :in
  type :array do
    prototype :integer
  end
end.create

role_in.set_value [0, 1, 2]
assert_equal 'users.role IN (0, 1, 2)', role_in.to_query(User.arel_table).to_sql.unquote
```

### Nullness predicate
Another simple predicate type is `:nullness_predicate` which uses
different underlying implementation but its interface is similar to that of fixed operator
predicates. Here is how to create a nullness predicate:

```ruby
profile_null = Query::NullnessPredicateBuilder.instance(:id).include do
  arel_table Profile.arel_table
end.build.create
profile_null.set_value true
assert_equal 'profiles.id IS NULL', profile_null.to_query(User.arel_table).to_sql.unquote
profile_null.set_value false
assert_equal 'NOT ("profiles"."id" IS NULL)', profile_null.to_query(User.arel_table).to_sql
```

### Variable operator predicate
Variable operator predicate offers a somewhat richer interface that allows user
to choose the operator. Naturally it is also more complex to set up, as we’ve 
seen in the relation example. Let’s reuse that example here to show how to specify allowed 
operators in the definition block:

```ruby
definition = Query::VariableOperatorPredicateBuilder.instance(:role_variable_operator, attr: :role).include do
  operators :equal, :greater_than_or_equal, :less_than_or_equal
  type :value, :integer
  optional
end.build
```

### Exists predicate
The library also defines 'exists predicate' that filters records from certain
table on existence or non-existence of related records in other table. Relation
between the two tables is established in the `#related` block, with 
syntax equal to the one used for joins. If the relation is based on
something more complex than equality of two columns, SQL literal, Arel node or 
a proc can be passed to the `#on` method.

```ruby
definition = Query::ExistsPredicateBuilder.instance(:subscription_channel_exists).include do
  arel_table Subscription.arel_table
  related { on(:id).eq(:user_id) }
  fixed_operator_predicate :channel_equal, attr: :channel do
    operator :equal
    type :value, :integer
  end
end.build
_, subscription_channel_exists = definition.from_input({ channel_equal: 5 }, :backend)

expected = <<~SQL
  EXISTS
   (SELECT * FROM subscriptions
   WHERE (subscriptions.channel = 5)
   AND (users.id = subscriptions.user_id)
   LIMIT 1)
SQL
sql = subscription_channel_exists.to_query(User.arel_table).to_sql
assert_equal expected.unformat, sql.unquote
```
When the relation builds this query, it passes its own base table in to be
used as the outer table of the relation. It is not always what we want, 
for example when the outer table is one of the joined tables. 
In such case we have to declare the outer table explicitly as in the following listing:

```ruby
subscription_channel_exists = ExistsPredicateBuilder.instance(:subscription_channel).include do
  outer_table User.arel_table
  arel_table Subscription.arel_table
  related { on(:id).eq(:user_id) }
  fixed_operator_predicate :channel do
    operator :equal
    type :value, :integer
  end
end.build.create
```

Exists predicate tests for existence by default. There is no `ExistsNotPredicate` though.
Default behaviour can be altered and even controlled dynamically by adding `existence` 
parameter to the definition. It is a regular value parameter accepting `:some` and 
`:none` values and as such it responds to `default` and `local` methods. So to 
convert an exists predicate to an exists-not predicate, we need to add the 
following to the definition:

```ruby
subscription_channel_exists_not = ExistsPredicateBuilder.instance(:subscription_channel).include do
  arel_table Subscription.arel_table
  related { on(:id).eq(:user_id) }
  fixed_operator_predicate :channel do
    operator :equal
    type :value, :integer
  end
  existence do 
    local :none 
  end
end.build.create
```

If we omitted the call to `local`, the option could be set dynamically from the input.

### Custom predicate
The library only provides DSL for a handful of most common predicates. For cases that 
are not covered by the DSL, there is the custom predicate. It can be derived from whatever
basic parameter type is registered with `Builder` and needs to define a `#to_query` block that 
constructs an SQL string or Arel object representing the predicate. 

Suppose we want to use function `unaccent` to transform the stored value and 
besides that, give user the liberty to choose exact match or pattern matching 
to filter results. We could use definition such as this:

```ruby
definition = Query::CustomPredicateBuilder.instance(:search_by_name).include do
  type :struct do
    add :string, :search
    add :symbol, :operator do
      constrain :enum, %i(equal like)
      default :equal
    end
  end
  to_query do |table, _context|
    search = self[:search].unwrap
    return if search.empty?

    search = I18n.transliterate(search)

    column = table[:name]
    unaccent = Arel::Nodes::NamedFunction.new('unaccent', [column])
    if self[:operator].unwrap == :like
      unaccent.matches("%#{search}%")
    else
      unaccent.eq(search)
    end
  end
end.build

_, parameter = definition.from_input({ search: 'John', operator: 'like' })
assert_equal "unaccent(users.name) LIKE '%John%'", parameter.to_query(User.arel_table).to_sql.unquote
```

We return Arel node from the `#to_query` block but it is equally
valid to return raw SQL string. Note that `nil` is also a legal return value 
which we can use in case we want the predicate to be skipped. 

### Polymorph predicate
Polymorph predicate is a container that can hold exactly one of a number of declared predicate
types. It is at its most powerful in connection with array grouping so we’ll refer
you to the [corresponding section](#array_grouping) for a comprehensive example. 

### Grouping
To combine predicates together we use grouping parameter, which comes in two variants:
`StructuredGrouping` and `ArrayGrouping`. Structured grouping consists of a definite
number of named predicates while array grouping can hold any number of predicates 
of homogeneous type. This is actually more useful than it sounds since predicates 
allow for some variance themselves and there is also the polymorph parameter to 
accommodate any number of different types of predicates. Note that `Relation` and 
`ExistsPredicate` are implemented in terms of grouping, so what is to be said 
here applies to those too. 

#### Structured grouping
To define a predicate within a Grouping, we call `predicate :predicate_name` or
`"#{predicate_name}_predicate"`. This holds for any predicate class registered 
using `PredicateRegistry.register_predicate`.

For every type of grouping, a grouping operator must be defined (unless it consists 
of at most one single predicate). Operator is an ordinary parameter, it can have or not 
have a default value and it also can be defined as local. This way the grouping operator
may be left to be chosen by the user, it may be made optional (with default), 
or it can be fixed, out of reach from the user.

Let’s see structured grouping in action: 

```ruby
definition = Query::StructuredGroupingBuilder.instance(:grouping).include do
  operator
  fixed_operator_predicate :first_name_like, attr: :first_name do
    operator :like
    type :value, :string
    optional
  end

  fixed_operator_predicate :last_name_like, attr: :last_name do
    operator :like
    type :value, :string
    optional
  end
end.build

assert_equal exp.unformat, query.to_sql.unquote
```

Even if we don’t set any specific options on the grouping 
operator we still need to declare it within the definition block. We don’t 
have to if the grouping contains no more than one predicate.

Now let’s initialize the grouping from hash with operator set to `:and` and 
have it produce correctly formed SQL expression:

```ruby
input = { operator: :and, first_name_like: 'John', last_name_like: 'Doe' }
_, structured_grouping = definition.from_input(input, context: :backend)
exp = <<~SQL
  (users.first_name LIKE '%John%' AND users.last_name LIKE '%Doe%')
SQL

query = structured_grouping.to_query(User.arel_table)
assert_equal exp.unformat, query.to_sql.unquote
```

#### <a name="array_grouping">Array grouping</a>
Array grouping takes an arbitrary number of predicates of given type
and combines them into a query. Here is an example of array grouping along
with a polymorph predicate:

```ruby
definition = Query::ArrayGroupingBuilder.instance(:grouping).include do
  operator
  prototype :polymorph_predicate do
    type :fixed_operator_predicate, :name_like, altn: :nlk, attr: :name do
      type :value, :string
      operator :like
    end
    type :variable_operator_predicate, :role_variable_operator, altn: :rvop, attr: :role do
      type :value, :integer
      operators :less_than_or_equal, :equal, :greater_than_or_equal
    end
  end
  optional
end.build


_, p = definition.from_input({ a: [{ nlk: 'Jane' }, { rvop: { val: 4, op: :lteq }}], op: :and })
exp = <<~SQL
  (users.name LIKE '%Jane%' AND users.role <= 4)
SQL

assert_equal exp.unformat, p.to_query(User.arel_table).to_sql.unquote
```

### Join
Two basic types of join are supported, inner join and left
outer join. The library makes no attempt at guessing the columns
to join on, the join clause must be always fully specified. For 
the simple case where we are joining on equality of two columns, 
there is syntax sugar:

```ruby
relation = Builder.define_relation :users do
  model User
  join_table Profile.arel_table, :outer do
    on(:id).eq(:user_id)
  end
  # ...
end.create

exp = <<~SQL
  SELECT * FROM users LEFT OUTER JOIN profiles ON users.id = profiles.user_id
SQL
assert_equal exp.unformat, relation.build_select.to_sql.unquote
``` 

If you need to join on anything more complex that equality of two columns, 
you’ll have to pass either an SQL literal or Arel node or a proc into the `#on` method.

```ruby
relation = Builder.define_relation :users do
  model User
  join_table Profile.arel_table, :inner do
    on("users.id = profiles.owner_id AND profiles.owner_type = 'User'")
  end
  # ...
end.create

exp = <<~SQL
  SELECT * FROM users INNER JOIN profiles ON (users.id = profiles.owner_id AND profiles.owner_type = 'User')
SQL
assert_equal exp.unformat, relation.build_select.to_sql.unquote
```

### Ordering
Ordering is defined for a relation by invoking `#order` within 
the definition. Each of the columns to order on must be declared inside
the definition block with a call to `#column` method. The first parameter 
is the column name and the second is either `:asc` or `:desc`, meaning
default ordering for this column. Optional parameters are: 

- `:arel_table`, which is needed if the column comes from other table than 
the relation’s base table. If the column is computed and there is no underlying
table, pass in `:none` symbol instead.
- `:nulls` option determines the approach to take in presence of nulls, 
allowed values being `:default`, `:first` and `:last`.
- `:expression` is the literal SQL expression to use instead of the column name.
Acceptable values are string, Arel node or a proc taking two arguments, `|arel_table, context|`, 
returning string or Arel node.  

Ordering can have default just like any other parameter, expected values are 
two element tuples containing column name and ordering type.

All of the options explained above are shown in the following snippet:
 
```ruby
relation = Builder.define_relation :users do
  model User
  # ...
  order do
    column :created_at, :desc
    column :email, :asc
    column :name, :asc, arel_table: Profile.arel_table, nulls: :last
    column :ranking, :asc, arel_table: :none
    column :nickname, :asc, arel_table: :none, expression: 'profiles.nickname COLLATION "C"'
    default [:created_at, :desc], [:email, :asc]
  end
end
```

To retrieve variables for the reordered page from a relation we can do the following:

```ruby
vars = relation.toggle(:name)
```

Since the `:name` column was defined with ascending default ordering, values will 
follow this sequence: `:none` -> `:asc` -> `:desc`. If you want to use 
different value out of the regular order, you can call:

```ruby
vars = relation.reorder(:name, :desc)
```  

These helper functions will dump all parameter values, not only ordering, into the
hash, preserving other query parameters the user might have passed in. Assuming 
we are going to incorporate the hash into links to other locations, this
is probably what we want to be able to pick the values up from URI variables later. 

Call `relation[:ordering].by_columns` to get a hash where keys are column names 
and values indicate current ordering for each column and its position in the ordering clause. 
It may be useful if you are marking column headers in your view with arrows or other visual 
hints to indicate ordering.

### Pagination
This library implements two standard pagination methods: offset based and keyset based.
For each of them there are helpers on the relation to fetch request variables
that can be used to create a link to a specific page. The following ones are available for 
both methods: `#current`, `#first`, `#last` to create links pointing to the current, 
first and last page. Another helper, `#limit_at(limit)`, returns page variables with updated limit. 

#### Offset based pagination
Offset based pagination is the default, so to set it up just call `paginate 10, 100` within
the definition block of a relation. The two arguments represent default limit and maximum limit. 
Page helpers specific for this method are: `#previous(delta = 1)` and `#next(delta = 1, count: nil)`. 
To test whether certain page exists, use `#has_previous?(delta = 1)`, 
`#has_next?(delta = 1, count:)`. You can also retrieve current position using `#page_no` method.

#### Keyset based pagination
When using keyset pagination, you need to indicate what keys will serve as the base 
for the cursor. Typically this is a single key, the primary key of the underlying database table, 
but if you happen to use composite primary key, you must specify all its components:

```ruby
paginate 10, 100, method: :keyset do 
  key :integer, :part_id, :asc 
  key :integer, :company_id, :asc
  base64
end
```

The call to `#base64` at the end is optional, it tells the parameter to marshal into a base64 string instead
of a hash, which makes its frontend representation somewhat easier to handle in views and forms. 

This declaration can be followed with a call to `#order` to define additional columns to order on. 
When building the query, relation will fetch all values needed to build a complete cursor 
for the particular ordering into a CTE using the declared primary key or keys. 

There are a few rules to observe in order to obtain correct results: 
1) You cannot order on computed columns that are defined in the select list and only 
aliased in the ordering clause. You will have to pass the full expression, 
not only an alias, for the column into the ordering definition. 
2) If you want to order on a nullable column, you always have to specify
null handling policy (other than `:default`).
3) You can't reorder the relation received from the `#build_relation` call and
you can't apply any additional scopes onto it.
   
Assuming you have a nullable, computed `:name` column, the ordering definition may look like this:

```ruby
name_expression = <<~SQL
  (CASE 
  WHEN users.last_name IS NULL AND users.first_name IS NULL THEN NULL
  ELSE 
    rtrim(ltrim(
    concat(
      coalesce(users.last_name, ''), 
      ' ', 
      coalesce(users.first_name, ''))))
  END)
SQL

order do 
  column :name, :asc, nulls: :last, arel_table: :none, expression: name_expression
end
```

Page helpers defined for keyset pagination method are `#before(keyset)` and `#after(keyset)`. 
You can use them in your controllers or views like so:

```ruby
@previous = if @parts.length.positive?
  first = @parts.first
  keyset = { part_id: first.part_id, company_id: first.company_id }
  @prms.relation(:parts).before(keyset)
end
```

Keyset pagination in this basic form offers only limited navigation options for the user – a link to
the previous, next, first and last page, without even knowing whether those pages exist. You will need 
two extra queries into the database to get information about pages potentially lying before and after the 
cursor. If you are willing to pay the extra cost, the relation has a helper method `#keysets` for that
with the following signature: 

```ruby
def keysets(limit, direction, keyset, scope: nil, context: Restriction.blanket_permission, &block)
```

The `limit` argument indicates how many records you want it to fetch, direction can be one of the `:before` and
`:after` to tell the relation to seek backwards or forwards. The third argument is a keyset to 
serve as the starting point of the search. You can also pass a scope and a context object into the
method to further restrict the search in the same way you would with the `#build_relation` method.

The result of the query is either a `BeforeKeysets` or `AfterKeysets` object containing
the raw result from the database. Since different database adapters serve results in different 
form, you can pass an optional block into the `#keysets` method to transform the result
into the canonical hash that you later can pass into the `#after` method. Given an adapter 
returning tuples from the database like the one used with MySQL, the transformation block may 
look like this:

```ruby
transform = proc do |tuple|
  { part_id: tuple[0], company_id: tuple[1] }
end
```

To retrieve a keyset for a particular page, use `#page` method on the container object with
number of pages to skip and a limit as arguments. If requested page exists, you will obtain the
keyset after which it is to be found, otherwise it returns `nil`.

## <a name="integration">Integration with Rails</a>
This library was conceived primarily as an extension for Rails but there is 
no strong opinion as to where and how to plug it into Rails. We can provide 
only suggestions and examples here. 

There are two modules intended to integrate with client code: `ParameterDefiner`
and `ParameterUser`. The easiest path to get the library working is to include 
both of them into a controller, define parameters in the controller body
and populate parameters in a `#before_action` callback. It takes just 
a few steps to do that. First, include all necessary modules 
in a superclass of your controllers, declare the `#before_action` callback 
and define the corresponding method that will transform
`ActionController::Parameters` into a parameter object:

```ruby
class ApplicationController < ActionController::Base
  include ParamsReady::ParameterUser
  include ParamsReady::ParameterDefiner

  before_action :populate_params

  def populate_params
    # Provide formatting information
    format = ParamsReady::Format.instance(:frontend)
    # If initialization of some parameters requires additional
    # data, pass them in within the context object
    data = { current_user: current_user, authority: authority }
    context = ParamsReady::InputContext.new(format, data)

    result, @prms = populate_state_for(action_name.to_sym, params, context)
    if result.ok?
      # At this point, parameters are guaranteed to be correctly initialized
      Rails.logger.info("Action #{action_name}, parameters: #{@prms.unwrap}")
      # It is recommended to freeze parameters after initialization
      @prms.freeze
    else
      params_ready_errors = result.errors
      # Error handling goes here ...
    end
  rescue AuthenticationError, AuthorizationError, NotFoundError, ServerError, SessionExpired => e
    # Error handling for specific errors ...
  rescue StandardError => e
    # Error handling for generic errors ...
  end
end
```

The setup shown in the previous listing makes it possible to define parameters 
directly in the controller:

```ruby
class UsersController < ApplicationController
  define_parameter :struct, :user do
    no_output
    add :string, :email do
      optional
    end
    add :string, :name do 
      optional 
    end
    add :integer, :role do
      optional
      constrain :enum, User.roles.values
    end
    add :integer, :status do
      optional
      constrain :enum, User.statuses.values
    end
  end
end
```

This is fine if there are just a handful of simple parameters. But with very complex 
parameters the setup would get way too wordy and would shadow the actual 
controller logic. It is recommendable then to define parameters at some other place
and fetch them from there into your controllers:

```ruby
class UserParameters
  include ParamsReady::ParameterDefiner
  define_relation :users do
    operator { local :and }
    model User
    fixed_operator_predicate :name_match, attr: :name do
      type :value, :non_empty_string
      operator :like
      optional
    end

    fixed_operator_predicate :email_match, attr: :email do
      type :value, :non_empty_string
      operator :like
      optional
    end

    paginate 10, 100
    order do
      column :email, :asc
      column :name, :asc, nulls: :last
      column :role, :asc
      default [:email, :asc], [:role, :asc]
    end
    default :inferred
  end
end

class UsersController < ApplicationController
  # ...
  include_relations UserParameters
end
```

To make the controller actually capture parameters and relations, you have to
declare usage for particular actions:

```ruby
class UsersController < ApplicationController
  # ...
  use_parameter :user, only: %i[create update]
  use_relation :users, except: %i[suggest]
end
```

An alternative way to declare usage is the `#action_interface` method. 
You can pass individual parameter and relation names or list of those names 
to the method as named arguments or you can call singular- or plural-named methods 
in a block: 

```ruby
# using named arguments
class UsersController < ApplicationController
  action_interface(:create, :update, parameter: :user, relations: [:users, :posts])
end

# using a block:
class UsersController < ApplicationController
  action_interface(:create, :update) do 
    parameter :user 
    relations :users, :posts
  end
end
```

We’ll now show an implementation of the concept mentioned above in the [URI variables](#uri_variables) 
section. We want to have a posts controller that would retain information received from the users
controller along with its own filters, ordering, and pagination, and inject these data into links leading
out from the index page.
We already have the users controller so the last missing pieces are the posts controller and the
index view. For simplicity, we define the posts relation inside the controller’s body:

```ruby
class PostsController < ApplicationController
  include_relations UsersParameters
  use_relation :users, only: [:index, :show]

  define_relation :posts do
    operator { local :and }

    fixed_operator_predicate :user_id_eq, attr: :user_id do
      type :value, :integer
      operator :equal
      optional
    end

    join_table User.arel_table, :inner do
      on(:user_id).eq(:id)
    end
    fixed_operator_predicate :subject_match, attr: :subject do
      type :value, :non_empty_string
      operator :like
      optional
    end
    paginate 10, 100
    order do
      column :email, :asc, arel_table: User.arel_table
      column :subject, :asc
      default [:email, :asc], [:subject, :asc]
    end
  end
  use_relation :posts, only: [:index, :show]

  define_parameter :integer, :id
  use_parameter :id, only: [:show]

  def index
    @posts = @prms.relation(:posts).build_relation(include: [:user], scope: Post.all)
    @count = @prms.relation(:posts).perform_count(scope: Post.all)
  end

  def show
    @post = Post.find_by id: @prms[:id].unwrap
  end
end
```

The root parameter object offers similar interface as `Relation` for retrieving 
variables for specific page and ordering. It is different in that the parameter 
object can contain various relations so the relation’s name must be specified. 
We use this feature along with the `#for_frontend` and `#flat_pairs` methods to create 
the index view with all necessary links and controls:

```erb
<% reset = ParamsReady::Restriction.permit(:users, posts: [:user_id_eq]) %>
<h1><%= link_to 'Posts', posts_path(@prms.for_frontend(restriction: reset)) %></h1>
<div><%= link_to 'Back to users', users_path(@prms.for_frontend(restriction: ParamsReady::Restriction.permit(:users))) %></div>

<%= form_tag posts_path, method: 'get', class: 'filter-form', id: 'posts-filters' do %>
  <% out = ParamsReady::OutputParameters.decorate(@prms) %>
  <% out.flat_pairs(restriction: reset).each do |name, value| %>
    <%= hidden_field_tag name, value %>
  <% end %>
  <%= label_tag :subject_match, 'Subject' %>
  <%= text_field_tag out[:posts][:subject_match].scoped_name, out[:posts][:subject_match].format %><br/>
  <%= submit_tag 'Submit' %>
<% end %>
<table class="admin-table">
  <thead>
  <tr>
    <td></td>
    <td><%= link_to 'Author', posts_path(@prms.toggle(:posts, :email)) %></td>
    <td><%= link_to 'Subject', posts_path(@prms.toggle(:posts, :subject)) %></td>
  </tr>
  </thead>
  <tbody>
  <% current = @prms.current %>
  <% @posts.each do |post| %>
    <tr>
      <td><%= link_to 'Show', post_path(post, current) %></td>
      <td><%= post.user.email %></td>
      <td><%= post.subject %></td>
    </tr>
  <% end %>
  </tbody>
</table>

<div class="pagination">
  <div><%= "Showing page #{@prms.page_no(:posts)} out of #{@prms.num_pages(:posts, count: @count)}" %></div>
  <div><%= link_to 'First', posts_path(@prms.first(:posts)) %></div>
  <div><%= link_to 'Previous', posts_path(@prms.previous(:posts, 1)) if @prms.has_previous?(:posts, 1) %></div>
  <div><%= link_to 'Next', posts_path(@prms.next(:posts, 1)) if @prms.has_next?(:posts, 1, count: @count) %></div>
</div>
```

Interesting points here are the links leading out from the page:
- At the top of the page we have a link that resets the posts search but retains users pagination
and the id of the user we are interested in. 
- Another link leads back to the users index and we drop
all posts information there.
- There is a very simple form for filtering posts, containing a single search field 
for the subject. We pass the users pagination into the form via hidden fields so that 
it isn’t lost when user submits new search.
- We incorporate ordering controls in the table header using the `#toggle` method.
- Each row in the table contains a link to the detail page that maintains filtering 
and pagination for both users and posts, so it is possible to get back to this 
very same page from the detail view later on.
- Finally, at the bottom we can see some rudimentary pagination controls. 

This way users can navigate smoothly through the whole tree of an administration system and 
be able to get back to pages they’ve seen.
 
## Extending parameters
It is possible to extend parameters but it is not a straightforward job. In most cases
it amounts to subclassing as many as three classes: one for builder, definition and
the parameter itself. If you are interested you may have a look at the implementation
of `StructuredGrouping` and `OrderingParameter`, subclasses of `StructParameter` and 
`ArrayParameter` respectively, to see how this is done.
An easier way to add functionality to a parameter is to call `#helper` method 
within the parameter definition. This will add a new public method to each instance created
from the definition:

```ruby
p = Builder.define_boolean :flag do
  helper :display_value do |translator|
    translator.t(unwrap, scope: 'common')
  end
end.create

p.set_value true
assert_equal 'YES', p.display_value(I18n)
```

In case you need to transform some specific data formats to 
fit into predefined parameter types, you might not always have to
subclass a parameter. To transform data into the canonical form and back into the output
format, parameters use object called `Marshaller`. For all container types, it is possible 
to define a custom marshaller and plug it in within the definition block. 

The marshaller that transforms strings to arrays was considered so useful, 
it has actually been built into the library. Following code configures the string
marshaller in place of the default one:

```ruby
d = Builder.define_array :stringy do
  prototype :string

  marshal using: :string, separator: '; ', split_pattern: /[,;]/
end

_, p = d.from_input('a; b, c')
assert_equal %w[a b c], p.unwrap
assert_equal 'a; b; c', p.format(Format.instance(:frontend))
```

Another alternative ready-to-use marshaller is the base64 marshaller
for struct parameter:

```ruby
definition = Builder.define_struct :parameter do
  add :integer, :int
  add :string, :str
  marshal using: :base64
end

_, parameter = definition.from_input({ int: 1, str: 'foo' }, context: :backend)

base64 = 'eyJpbnQiOiIxIiwic3RyIjoiZm9vIn0='
assert_equal base64, parameter.for_output(:frontend)
assert_equal parameter, definition.from_input(base64)[1]
```

To get some idea about how custom marshallers are defined, you may 
have a look at this file: `test/marshaller/custom_marshallers.rb`

## Project status
This project evolved for a period of around six years. It has undergone
various rounds of refactoring and changed name several times. 
It has been deployed in production before but current version adds lots
of new features that are largely untested on live projects. That’s the
reason why the version count has been set back to 0.0.1 again. 

## Compatibility
The library has been tested against 2.5.8, 2.6.6, 2.7.2 and 3.0.0 Ruby versions.
It has been successfully integrated into Rails 6.x projects using MySQL and PostgreSQL
database management systems.

## License
This project is licensed under the MIT license
