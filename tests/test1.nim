import validation
import re
import options

type TestObject* = object
    something* {.lessThan(50).}: int
    stringyfield {.matchesPattern("hello|bye").}: string
    greaterThanSomething {.greaterThan(this.something).}: int
    shouldMatch {.matchesPattern(this.stringyfield).}: string


generateValidators(TestObject)

let positiveValidation = TestObject(something: 20, stringyfield: "hello", greaterThanSomething: 25, shouldMatch:"hello").validate()


echo "positive validation ", positiveValidation
doAssert(positiveValidation.errorCount == 0)
doAssert(positiveValidation.hasErrors == false)
echo "postive validation passed"

let negativeValidation = TestObject(something: 100, greaterThanSomething: 5, shouldMatch: "nope").validate()

echo "negative validation ", negativeValidation
doAssert(negativeValidation.errorCount == 3)

doAssert(negativeValidation.hasErrors == true)

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


for error in validationNestedNegative.validationErrors:
    echo error.message


let validationNestedPositive = WrapperObject(a: 30, b: "hello", child: TestObject(something: 30, stringyfield: "bye", shouldMatch: "bye", greaterThanSomething:50)).validate()

echo validationNestedPositive
doAssert(validationNestedPositive.errorCount == 0)
doAssert(validationNestedPositive.hasErrors == false)


template notAValidation(something: string) {.pragma.}

proc notAValidation(something: string): void =
    echo something


template customValidation(oneOf: openArray[int]) {.pragma.}

proc customValidation(field: int, oneOf: varargs[int]): Option[ValidationError] =
    for value in oneOf:
        if value == field:
            return none(ValidationError)
    
    return someValidationError("Custom validation failure")

type
    CustomObj = object
        field {.customValidation(@[2, 4, 6]), notAValidation("blah").}: int

generateValidators(CustomObj)

echo "CUSTOM VALIDATION RESPONSE: ", customValidation(5, @[1,2,3])


let customValidationPositive = CustomObj(field: 2).validate()
doAssert(customValidationPositive.errorCount == 0)
doAssert(customValidationPositive.hasErrors == false)

let customValidationNegative = CustomObj(field: 500).validate()
doAssert(customValidationNegative.errorCount == 1)
doAssert(customValidationNegative.hasErrors == true)


