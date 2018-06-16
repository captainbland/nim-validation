import options
import strutils
import re

type ValidationError* = object
    message*: string

proc someValidationError*(errorString: string): Option[ValidationError] =
    return some(ValidationError(message: errorString))

template validation(condition: stmt, msg: string): stmt =
    if not(condition):
         return someValidationError(msg)
    else: return none(ValidationError)
    

type ValidationContext*[T] = object
    field*: T

proc newValidationContext*[T](field: T): ValidationContext[T] =
    return ValidationContext[T](field: field)


template greaterThan* (x: untyped) {.pragma.}

proc greaterThan* [T](field, x: T): Option[ValidationError] = 
    validation(ctx.field > x, "$1 was not less than $2".format($field, $x))


template lessThan*(x: untyped) {.pragma.}

proc lessThan* [T](field:T, x: T): Option[ValidationError] = 
    if not (field < x):
        return someValidationError("$1 was not less than $2".format($field, $x))
    else: return none(ValidationError)

template matchesPattern* (pattern: string) {.pragma.}

proc matchesPattern* (field: string, pattern: string): Option[ValidationError] = 
    if not field.match(re(pattern)):
        return someValidationError("$1 does not match pattern".format($field))
    else: return none(ValidationError)

template notNil* {.pragma.}

proc notNil* [T](field: T): Option[ValidationError] =
    if(field.isNil):
        return someValidationError("Object is nil")
    else: return none(ValidationError)

# For nested templates
template valid* {.pragma.}

proc valid* [T](field:T): Option[ValidationError] =
    let validation = field.validate()
    echo "Validating inner object, field: ", field, "v: ", validation.validationErrors
    if(validation.hasErrors):
        echo "inner object has errors"
        return someValidationError("Nested object had validation errors $1".format($field))
    else: return none(ValidationError)