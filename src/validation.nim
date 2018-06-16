
# Nim object field validation library
# Copyright (C) 2018  CaptainBland (JS)

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

import json, macros
import sequtils
import future
import typeinfo
import strutils
import options

import validator_defs/validator_defs
export validator_defs 

type ErrorAccumulator* = object
    validationErrors*: seq[ValidationError]

proc newErrorAccumulator*(): ErrorAccumulator =
    return ErrorAccumulator(validationErrors: @[])

proc addError*(self: var ErrorAccumulator, error: Option[ValidationError]): void =
    echo "Calling add"
    if error.isSome():
        self.validationErrors.add(error.get())

proc hasErrors*(accumulator: ErrorAccumulator): bool = accumulator.validationErrors.len > 0

proc errorCount*(accumulator: ErrorAccumulator): int = accumulator.validationErrors.len

proc `$`(accumulator: ErrorAccumulator): string =
    accumulator.validationErrors.map(e => e.message).join(",")


type
    PragmaDef = object
        call: NimSym
        params: seq[NimNode]

    Field = object
        name: string
        t: NimSym
        pragmas: seq[PragmaDef]
 
    
    TypeInfo = object
        typename: string
        fields: seq[Field]

proc `$`(typeInfo: TypeInfo): string =
    echo "TypeInfo of ", typeInfo.typename, ": ("
    for field in typeInfo.fields:
        echo "  ", [field.name, $field.t].join(", "), "; pragmas: ("
        for pragma in field.pragmas:
            echo "    ", $pragma.call, " params: ", pragma.params.len
        echo "  )"
    echo ")"


#Lookup index filter by NimNodeKind
proc `[]`(x: NimNode, kind: NimNodeKind): seq[NimNode] {.compiletime.} =
    return toSeq(x.children).filter(c => c.kind == kind )

proc safeGet(x: seq[NimNode], idx: int): Option[NimNode] {.compiletime.} =
    if idx < x.len:
        return some(x[idx])
    else: return none(NimNode)

proc `[]`(x: Option[NimNode], kind: NimNodeKind): seq[NimNode] {.compiletime.} =
    if x == none(NimNode):
        return @[]
    else:
        return x.get()[kind]

proc getOr[T](opt: Option[T], alternative: T): T =
    if opt == none(T):
        return alternative
    else:
        return opt.get()

proc extract_type_info(t: typedesc): TypeInfo {.compiletime.} =
    
    echo getTypeInst(t)[1].symbol.getImpl.treeRepr
    var x = getTypeInst(t)[1].symbol.getImpl
    echo "The name of the thing is ", $x[nnkSym][0]

    echo x.treeRepr
    var recList: NimNode
    recList = case x[2].kind
        of nnkRefTy:
            x[nnkRefTy][0][nnkObjectTy][0][nnkRecList][0]
        of nnkObjectTy: 
            x[nnkObjectTy][0][nnkRecList][0]
        else: 
            echo "Invalid object. bugs incoming"
            echo x[0].kind
            NimNode()
    
    var fields: seq[Field] = @[]
    let identDefs = recList[nnkIdentDefs]
    for node in identDefs:
        echo "This node has ", toSeq(node.children).map(n => n.kind)
        case node[0].kind:
            of nnkIdent: 
                let fieldName = $node[nnkIdent][0]

                let t = node[nnkSym][0].symbol
                fields.add(Field(name:fieldName, t:t))
                echo "name: ", fieldName, " t: ", t
            of nnkPragmaExpr: 
                let t = node[nnkSym][0].symbol
                let fieldName = $node[nnkPragmaExpr][0][nnkIdent][0]
                
                var pragmas: seq[PragmaDef] = @[]

                for call in node[nnkPragmaExpr][0][nnkPragma][0][nnkCall]:
                    echo "CALL[0]: ", call[0]
                    let pragmaCallName = symbol(call[0])

                    var pragmaParams: seq[NimNode] = @[]
                    for i in 1..(call.len() - 1):
                        pragmaParams.add(call[i])
                    
                    pragmas.add(PragmaDef(call: pragmaCallName, params: pragmaParams))
                    
                fields.add(Field(name:fieldName, t:t, pragmas: pragmas))

            else: 
                echo node.kind
                discard
    
    let name = $x[nnkSym][0]
    return TypeInfo(typename: name, fields: fields)


template typeTest*(myCall: untyped): untyped =
    addError(errors, myCall)

template newEcho(msg: string): expr =
    newCall(ident("echo")).add(newLit(msg))

template addCall(stmtList: typed, pragma: typed, field: typed): untyped =
    
    let pragmaCall = $pragma.call

    let validatorCall = newCall(ident($pragma.call))
                       .add(newDotExpr(ident("t"), ident(field.name)))

    for param in pragma.params: 
        validatorCall.add(param)

    let addToErrorsCall = newCall(newDotExpr(ident("errors"), ident("addError")))
                         .add(validatorCall)


    let callTypeTest = newCall(ident("typeTest")).add(validatorCall)
    let callCompiles = newCall(ident("compiles")).add(callTypeTest)
    let positiveBranch = newNimNode(nnkElifBranch).add(callCompiles).add(newStmtList(addToErrorsCall, newEcho("This is the positive branch")))

    let negativeBranch = newNimNode(nnkElse).add(newStmtList(newEcho("This is the negative branch: " & pragmaCall)));

    let whenStmt = newNimNode(nnkWhenStmt).add(positiveBranch).add(negativeBranch)


    echo "When statement: ", whenStmt.treeRepr


    stmtList.add(whenStmt)


macro generateValidators*(t: typedesc): untyped = 
    let typeInfo = extract_type_info(t)
    echo typeInfo
    
    let typeIdent = typeInfo.typeName.toNimIdent

    # generate validator calls:
    let stmtList = newStmtList()
    stmtList.add(parseStmt("var errors = newErrorAccumulator()"))
    for field in typeInfo.fields:
        for pragma in field.pragmas:
            addCall(stmtList, pragma, field)

    stmtList.add(parseStmt("errors"))
    
    let procDef = newProc(
        name = ident("validate").postfix("*"),
        params = [
        ident("ErrorAccumulator"),
        newIdentDefs(
            ident("t"),
            ident($typeIdent))
        ],
        body = stmtList
    )          
    
    result = newStmtList(procDef)


