# Nim Validation

## Description
Nim validation is a simple to use validation library that performs validations against nim objects using their field pragmas. This approach is inspired by libraries like Hibernate validators and Rust's validation library.

The aim of this library is to provide a simple, flexible mechanism for adding validations to your object fields - it does this without using RTTI and is type safe. It is easy to create custom validations, and currently has a small number of validations to demonstrate that it works. Nim Validation also works recursively with nested objects and supports cross field references in validations.

This library is still quite young so breaking changes may come in and there could be bugs. Licensed under GPLv3. Currently it will build under Nim 0.18.0.

## Examples

### Basic example
There are some examples in the tests directory. Here's one for a quick viewing. It shows a couple of the validators being used - lessThan which just determines if the field being validated is less than the value given, and matchesPattern which determines if the field matches a regex. 

In the test given here, you can see there is a single validation error where 100 is not less than 50.

```nim
type TestObject = object
    something {.lessThan(50).}: int # Here we use a field pragma to assert that this field should be less than 50
    stringyfield {.matchesPattern("hello|bye").}: string


# To generate the validation methods, you must call generateValidators on your type:
generateValidators(TestObject) 

# Then to validate the object you simply call validate() on it
let validation = TestObject(something: 100, stringyfield: "hello").validate()

# errorCount and hasErrors give you some information about the objects
doAssert(validation.errorCount == 1)
doAssert(validation.hasErrors == true)

# But you can also get a seq of the errors which you can use to extract messages to do with the errors
for error in validation.validationErrors:
    echo error.message

```

### Example validator

This is the less than validator included in this library. There are many others in validatordefs/validatordefs.nim - validators always need to have a pragma defined to keep the compiler happy - it should take the number of arguments in the field pragma expression. Then the proc definition should always take the field as the first parameter, followed by the parameters passed in in the pragma expression. E.g. the fields x in the template and the proc map to eachother.

```nim

template lessThan*(x: untyped) {.pragma.}

# Note here that we have one more parameter than in the pragma template.
# the first parameter is always the field that is being validated.
proc lessThan* [T](field: T, x: T): Option[ValidationError] = 
    if not (field < x):
        return someValidationError("$1 was not less than $2".format($field, $x))
    else: return none(ValidationError)

```

### Cross field validation

With nim-validation, you can validate a field against any of the other fields in the object - even those which are nested within the object. 
Using the `this` keyword to reference the current object, you can reference any of the fields on that object. In the below example, we access the 'something' field of a child object in the equals validation. This could be, for instance, a reference to a parent object.

There is an example in the tests for this, it is the below:

```nim
type
    WrapperObject = ref object of RootObj
        child* {.valid().}: TestObject
        b* {.matchesPattern("hello|bye").}: string
        a* {.lessThan(50), equals(this.child.something).}: int 

generateValidators(WrapperObject)

let validationNestedNegative = WrapperObject(a: 75, b: "slkjdf", child: TestObject(something: 70, stringyfield: "bye", shouldMatch: "hu")).validate()

echo "ValidatinNested: ", validationNestedNegative.errorCount, "msgs: ", validationNestedNegative
doAssert(validationNestedNegative.errorCount == 4)
doAssert(validationNestedNegative.hasErrors == true)

```

