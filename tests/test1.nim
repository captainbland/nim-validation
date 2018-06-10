import validation
import re
import options

type TestObject = object
    something {.lessThan(50).}: int
    stringyfield {.matchesPattern("hello|bye").}: string


generateValidators(TestObject)

let positiveValidation = TestObject(something: 20, stringyfield: "hello").validate()

doAssert(positiveValidation.errorCount == 0)
doAssert(positiveValidation.hasErrors == false)

let negativeValidation = TestObject(something: 100, stringyfield: "invalid").validate()

doAssert(negativeValidation.errorCount == 2)
doAssert(negativeValidation.hasErrors == true)

type
    WrapperObject = ref object of RootObj
        b {.matchesPattern("hello|bye").}: string
        a {.lessThan(5).}: int 
        c {.valid().}: TestObject

generateValidators(WrapperObject)

let validationNested = WrapperObject(a: 6, b: "slkjdf", c: TestObject(something: 70, stringyfield: "bye")).validate()

doAssert(validationNested.errorCount == 3)
doAssert(validationNested.hasErrors == true)

template customValidation(oneOf: varargs[int]) {.pragma.}

proc customValidation(field: int, oneOf: varargs[int]): Option[ValidationError] =
    for value in oneOf:
        if value == field:
            return none(ValidationError)
    
    return someValidationError("Custom validation failure")

type
    CustomObj = object
        field {.customValidation(2, 4, 6).}: int

generateValidators(CustomObj)


let customValidationPositive = CustomObj(field: 2).validate()
doAssert(customValidationPositive.errorCount == 0)
doAssert(customValidationPositive.hasErrors == false)

let customValidationNegative = CustomObj(field: 500).validate()
doAssert(customValidationNegative.errorCount == 1)
doAssert(customValidationNegative.hasErrors == true)


