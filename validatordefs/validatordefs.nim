import options
import strutils
import re

type ValidationError* = object
    message*: string

proc someValidationError*(errorString: string): Option[ValidationError] =
    return some(ValidationError(message: errorString))

template validation(condition: untyped, msg: string): untyped =
    if not(condition):
         return someValidationError(msg)
    else: return none(ValidationError)

template toString[T](input: T): string =
    if(input is nil): "NIL"
    else: $input

type ValidationContext*[T] = object
    field*: T

proc newValidationContext*[T](field: T): ValidationContext[T] =
    return ValidationContext[T](field: field)


template greaterThan* (x: untyped) {.pragma.}

proc greaterThan* [T](field, x: T): Option[ValidationError] = 
    if not (field > x):
        return someValidationError("$1 was not greater than $2".format(field.repr, x.repr))
    else: return none(ValidationError)


template lessThan*(x: untyped) {.pragma.}

proc lessThan* [T](field:T, x: T): Option[ValidationError] = 
    if not (field < x):
        return someValidationError("$1 was not less than $2".format(field.repr, x.repr))
    else: return none(ValidationError)

template matchesPattern* (pattern: untyped) {.pragma.}

proc matchesPattern* (field: string, pattern: string): Option[ValidationError] = 
    #assume it's optional by default, user should use notNil annotation otherwise
    # if pattern == nil:
    #     return none(ValidationError)
    if not match(field, (re(pattern))):
        return someValidationError("$1 does not match pattern".format(field.repr))
    else: return none(ValidationError)

template equals*(x: untyped) {.pragma.}

proc equals*[T](field: T, x:T): Option[ValidationError] = validation(field == x, "The fields are not equal")

template notNil* {.pragma.}

proc notNil* [T](field: T): Option[ValidationError] =
    if(field == nil):
        return someValidationError("Object is nil")
    else: return none(ValidationError)

# For nested templates
template valid* {.pragma.}

proc valid* [T](field:T): Option[ValidationError] =
    echo "calling nested validation thing"
    let validation = field.validate()
    if(validation.hasErrors):
        echo "inner object has errors"
        return someValidationError("Nested object had validation errors $1".format(field.repr))
    else: return none(ValidationError)
