
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
import sugar
import typeinfo
import strutils
import options

import validatordefs/validatordefs
export validatordefs 

const DEBUG = false

type ErrorAccumulator* = object
    validationErrors*: seq[ValidationError]

proc newErrorAccumulator*(): ErrorAccumulator =
    return ErrorAccumulator(validationErrors: @[])

template addError*(self: var ErrorAccumulator, error: Option[ValidationError]): void =
    when(DEBUG): echo "Calling add"
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
    when(DEBUG): echo "TypeInfo of ", typeInfo.typename, ": ("
    for field in typeInfo.fields:
        when(DEBUG): echo "  ", [field.name, $field.t].join(", "), "; pragmas: ("
        for pragma in field.pragmas:
            when(DEBUG): echo "    ", $pragma.call, " params: ", pragma.params.len
        when(DEBUG): echo "  )"
    when(DEBUG): echo ")"


#Lookup index filter by NimNodeKind
proc `[]`(x: NimNode, kind: NimNodeKind): seq[NimNode] {.compiletime.} =
    return toSeq(x.children).filter(c => c.kind == kind )

proc extractTypeInfo(t: NimNode): TypeInfo {.compiletime.} =
    
    when(DEBUG): echo getTypeInst(t)[1].symbol.getImpl.treeRepr
    var x = getTypeInst(t)[1].symbol.getImpl
    when(DEBUG): echo "The name of the thing is ", $x[nnkSym][0]

    when(DEBUG): echo x.treeRepr
    var recList: NimNode
    recList = case x[2].kind
        of nnkRefTy:
            x[nnkRefTy][0][nnkObjectTy][0][nnkRecList][0]
        of nnkObjectTy: 
            x[nnkObjectTy][0][nnkRecList][0]
        else: 
            echo "Invalid object. bugs incoming"
            when(DEBUG): echo x[0].kind
            NimNode()
    
    var fields: seq[Field] = @[]
    let identDefs = recList[nnkIdentDefs]
    for node in identDefs:
        when(DEBUG): echo "This node has ", toSeq(node.children).map(n => n.kind)
        case node[0].kind:
            of nnkIdent: 
                let fieldName = $node[nnkIdent][0]

                let t = node[nnkSym][0].symbol
                fields.add(Field(name:fieldName, t:t))
                when(DEBUG): echo "name: ", fieldName, " t: ", t
            of nnkPragmaExpr: 
                let t = node[nnkSym][0].symbol
                let fieldName = case(node[nnkPragmaExpr][0][0].kind):
                    of nnkIdent: $node[nnkPragmaExpr][0][nnkIdent][0]
                    of nnkPostfix: $node[nnkPragmaExpr][0][nnkPostfix][0][nnkIdent][1]
                    else:
                        echo "Couldn't figure out what name this ", node[nnkPragmaExpr][0].kind, "is. Bugs incoming!" 
                        "ERROR"

                var pragmas: seq[PragmaDef] = @[]

                for call in node[nnkPragmaExpr][0][nnkPragma][0][nnkCall]:
                    when(DEBUG): echo "CALL[0]: ", call[0]
                    let pragmaCallName = symbol(call[0])

                    var pragmaParams: seq[NimNode] = @[]
                    for i in 1..(call.len() - 1):
                        pragmaParams.add(call[i])
                    
                    pragmas.add(PragmaDef(call: pragmaCallName, params: pragmaParams))
                    
                fields.add(Field(name:fieldName, t:t, pragmas: pragmas))

            else: 
                when(DEBUG): echo node.kind
                discard
    
    let name = $x[nnkSym][0]
    return TypeInfo(typename: name, fields: fields)


template typeTest*(myCall: untyped): untyped =
    addError(errors, myCall)

template  newEcho(msg: string): untyped =
    newCall(ident("echo")).add(newLit(msg))

proc flattenDotExpr(dotExpr: NimNode): seq[NimNode] {.compileTime.} =

    var finished = false
    var currentExpr = dotExpr
    var idents: seq[NimNode] = @[]
    while not finished:
        if currentExpr[0].kind == nnkDotExpr:
            idents.add(currentExpr[1])
            currentExpr = currentExpr[0]
        else:
            finished = true
            idents.add(currentExpr[1])

    return idents
        
proc constructDotExpr(idents: var seq[NimNode]): NimNode {.compileTime.} =
    var dotExpr = newDotExpr(idents.pop(), idents.pop())

    while idents.len > 0:
        dotExpr = newDotExpr(dotExpr, idents.pop)
    
    return dotExpr


template addCall(stmtList: typed, pragma: typed, field: typed): untyped =
    
    let pragmaCall = $pragma.call

    let validatorCall = newCall(ident($pragma.call))
                       .add(newDotExpr(ident("t"), ident(field.name)))
    for param in pragma.params: 
        when(DEBUG): echo "Param repr ", param.repr
        when(DEBUG): echo param.treeRepr
        if(param.kind == nnkDotExpr):
            var idents = flattenDotExpr(param)
            idents.add(ident("t"))
            echo idents

            let newDotExpr = constructDotExpr(idents)
            when(DEBUG): echo newDotExpr.treeRepr

            validatorCall.add(newDotExpr)
        else: 
            validatorCall.add(param)

    let addToErrorsCall = newCall(newDotExpr(ident("errors"), ident("addError")))
                         .add(validatorCall)


    let callTypeTest = newCall(ident("typeTest")).add(validatorCall)
    let callCompiles = newCall(ident("compiles")).add(callTypeTest)
    let positiveBranch = newNimNode(nnkElifBranch).add(callCompiles).add(newStmtList(addToErrorsCall))

    let negativeBranch = newNimNode(nnkElse).add(newStmtList(newEcho("WARNING! Not adding a validation which would cause a compilation error: " & field.name & "." & pragmaCall)));

    let whenStmt = newNimNode(nnkWhenStmt).add(positiveBranch).add(negativeBranch)


    when(DEBUG): echo "When statement: ", whenStmt.treeRepr
    stmtList.add(whenStmt)


macro generateValidators*(t: typedesc): untyped = 
    let typeInfo = extractTypeInfo(t)
    when(DEBUG): echo typeInfo
    
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


