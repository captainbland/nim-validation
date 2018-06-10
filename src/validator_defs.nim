import options
import strutils
import re

type ValidationError* = object
    message*: string

proc someValidationError*(errorString: string): Option[ValidationError] =
    return some(ValidationError(message: errorString))

template greaterThan* (x: untyped) {.pragma.}

proc greaterThan* [T](field: T, x: T): Option[ValidationError] = 
    if not (field > x):
        return someValidationError("Field was not greater than ".format($field, $x))
    else: return none(ValidationError)

template lessThan*(x: untyped) {.pragma.}

proc lessThan* [T](field: T, x: T): Option[ValidationError] = 
    if not (field < x):
        return someValidationError("$1 was not less than $2".format($field, $x))
    else: return none(ValidationError)

template matchesPattern* (pattern: string) {.pragma.}

proc matchesPattern* (field: string, pattern: string): Option[ValidationError] = 
    if not field.match(re(pattern)):
        return someValidationError("$1 does not match pattern".format($field))
    else: return none(ValidationError)

template notNil* {.pragma.}

proc notNil* [T](field:T): Option[ValidationError] =
    if(field.isNil):
        return someValidationError("Object is nil")
    else: return none(ValidationError)

# For nested templates
template valid* {.pragma.}

proc valid* [T](field: T): Option[ValidationError] =
    let validation = field.validate()
    echo "Validating inner object, field: ", field, "v: ", validation.validationErrors
    if(validation.hasErrors):
        echo "inner object has errors"
        return someValidationError("Nested object had validation errors $1".format($field))
    else: return none(ValidationError)