import types, strutils, options, sequtils, tables

type
  NimCodeGenerator* = object
    indent: int
    inConstructor: bool
    stdlibPrefix: string
    inferredTypes: Table[string, string]

proc newNimCodeGenerator*(stdlibPrefix: string = "std"): NimCodeGenerator =
  result = NimCodeGenerator(
    indent: 0,
    inConstructor: false,
    stdlibPrefix: stdlibPrefix,
    inferredTypes: initTable[string, string]()
  )

proc getIndent(generator: NimCodeGenerator): string =
  "  ".repeat(generator.indent)

proc inferType(expr: Expression): string =
  if expr of NumberLiteral:
    let numLit = cast[NumberLiteral](expr)
    if numLit.value == numLit.value.int.float:
      return "int"
    else:
      return "float"
  elif expr of StringLiteral:
    return "string"
  elif expr of BooleanLiteral:
    return "bool"
  else:
    return "string"  # default fallback

proc analyzeTypes(generator: var NimCodeGenerator, program: Program) =
  for node in program.body:
    if node of ClassDeclaration:
      let classDecl = cast[ClassDeclaration](node)
      if classDecl.constructor.isSome:
        let constructor = classDecl.constructor.get()
        # Find constructor calls to infer parameter types
        for bodyNode in program.body:
          if bodyNode of VariableDeclaration:
            let varDecl = cast[VariableDeclaration](bodyNode)
            if varDecl.initializer of NewExpression:
              let newExpr = cast[NewExpression](varDecl.initializer)
              if newExpr.callee of Identifier:
                let callee = cast[Identifier](newExpr.callee)
                if callee.name == classDecl.name:
                  # Found constructor call, infer types from arguments
                  for i, arg in newExpr.arguments:
                    if i < constructor.parameters.len:
                      let paramName = classDecl.name & "." & constructor.parameters[i].name
                      let inferredType = inferType(arg)
                      generator.inferredTypes[paramName] = inferredType

proc generateExpression(generator: var NimCodeGenerator, expr: Expression): string
proc generateStatement(generator: var NimCodeGenerator, stmt: Statement): string

proc generateImportDeclaration(generator: var NimCodeGenerator, node: ImportDeclaration): string =
  var moduleName = node.path.replace(".fr", "").replace("./", "")
  
  if node.alias.isSome:
    return "import " & moduleName & " as " & node.alias.get()
  else:
    return "import " & moduleName

proc generateIdentifier(generator: var NimCodeGenerator, expr: Identifier): string =
  if expr.name == "self":
    return if generator.inConstructor: "result" else: "self"
  return expr.name

proc generateStringLiteral(generator: var NimCodeGenerator, expr: StringLiteral): string =
  let escapedValue = expr.value.replace("\"", "\\\"").replace("'", "\\'")
  return "\"" & escapedValue & "\""

proc generateNumberLiteral(generator: var NimCodeGenerator, expr: NumberLiteral): string =
  if expr.value == expr.value.int.float:
    return $expr.value.int
  else:
    return $expr.value

proc generateBooleanLiteral(generator: var NimCodeGenerator, expr: BooleanLiteral): string =
  return if expr.value: "true" else: "false"

proc generateCallExpression(generator: var NimCodeGenerator, expr: CallExpression): string =
  let callee = generator.generateExpression(expr.callee)
  var argStrings: seq[string] = @[]
  for arg in expr.arguments:
    argStrings.add(generator.generateExpression(arg))
  let args = argStrings.join(", ")
  
  if expr.callee of MemberExpression:
    let memberExpr = cast[MemberExpression](expr.callee)
    let obj = generator.generateExpression(memberExpr.obj)
    
    case memberExpr.property:
    of "parler":
      return obj & ".parler(" & args & ")"
    of "recupererNom":
      return obj & ".recupererNom()"
    else:
      return obj & "." & memberExpr.property & "(" & args & ")"
  
  return callee & "(" & args & ")"

proc generateMemberExpression(generator: var NimCodeGenerator, expr: MemberExpression): string =
  let obj = generator.generateExpression(expr.obj)
  return obj & "." & expr.property

proc generateBinaryExpression(generator: var NimCodeGenerator, expr: BinaryExpression): string =
  let left = generator.generateExpression(expr.left)
  let right = generator.generateExpression(expr.right)
  let op = expr.operator
  
  return "(" & left & op & right & ")"

proc generateNewExpression(generator: var NimCodeGenerator, expr: NewExpression): string =
  let callee = generator.generateExpression(expr.callee)
  var argStrings: seq[string] = @[]
  for arg in expr.arguments:
    argStrings.add(generator.generateExpression(arg))
  let args = argStrings.join(", ")
  return "new" & callee & "(" & args & ")"

proc generateArrayLiteral(generator: var NimCodeGenerator, expr: ArrayLiteral): string =
  var elements: seq[string] = @[]
  for element in expr.elements:
    elements.add(generator.generateExpression(element))
  
  if elements.len == 0:
    return "newSeq[string]()"
  
  return "@[" & elements.join(", ") & "]"

proc generateArrayAccess(generator: var NimCodeGenerator, expr: ArrayAccess): string =
  let array = generator.generateExpression(expr.array)
  let index = generator.generateExpression(expr.index)
  return array & "[" & index & "]"

proc generateNimCallExpression(generator: var NimCodeGenerator, expr: NimCallExpression): string =
  var nimCode = expr.code
  nimCode = nimCode.replace("\"", "\"")
  return nimCode

proc generateFunctionExpression(generator: var NimCodeGenerator, expr: FunctionExpression): string =
  var paramStrings: seq[string] = @[]
  for param in expr.parameters:
    let paramType = if param.name == "req": "Requete" else: "string"
    paramStrings.add(param.name & ": " & paramType)
  let params = paramStrings.join(", ")
  var output = "proc(" & params & "): string {.closure, gcsafe.} =\n"
  
  generator.indent += 1
  for stmt in expr.body:
    output.add(generator.generateStatement(stmt))
  generator.indent -= 1
  
  return output

proc generateExpression(generator: var NimCodeGenerator, expr: Expression): string =
  case expr.nodeType:
  of "Identifier":
    return generator.generateIdentifier(cast[Identifier](expr))
  of "StringLiteral":
    return generator.generateStringLiteral(cast[StringLiteral](expr))
  of "NumberLiteral":
    return generator.generateNumberLiteral(cast[NumberLiteral](expr))
  of "BooleanLiteral":
    return generator.generateBooleanLiteral(cast[BooleanLiteral](expr))
  of "CallExpression":
    return generator.generateCallExpression(cast[CallExpression](expr))
  of "MemberExpression":
    return generator.generateMemberExpression(cast[MemberExpression](expr))
  of "BinaryExpression":
    return generator.generateBinaryExpression(cast[BinaryExpression](expr))
  of "NewExpression":
    return generator.generateNewExpression(cast[NewExpression](expr))
  of "ArrayLiteral":
    return generator.generateArrayLiteral(cast[ArrayLiteral](expr))
  of "ArrayAccess":
    return generator.generateArrayAccess(cast[ArrayAccess](expr))
  of "NimCallExpression":
    return generator.generateNimCallExpression(cast[NimCallExpression](expr))
  of "FunctionExpression":
    return generator.generateFunctionExpression(cast[FunctionExpression](expr))
  else:
    raise newException(ValueError, "Unknown expression type: " & expr.nodeType)

proc generateAssignmentStatement(generator: var NimCodeGenerator, stmt: AssignmentStatement): string =
  let left = generator.generateExpression(stmt.left)
  let right = generator.generateExpression(stmt.right)
  return generator.getIndent() & left & " = " & right & "\n"

proc generateReturnStatement(generator: var NimCodeGenerator, stmt: ReturnStatement): string =
  let expr = generator.generateExpression(stmt.expression)
  return generator.getIndent() & "return " & expr & "\n"

proc generateVariableDeclaration(generator: var NimCodeGenerator, stmt: VariableDeclaration): string =
  let initializer = generator.generateExpression(stmt.initializer)
  let exportMark = if generator.indent == 0: "*" else: ""
  return generator.getIndent() & "var " & stmt.name & exportMark & " = " & initializer & "\n"

proc generateExpressionStatement(generator: var NimCodeGenerator, stmt: ExpressionStatement): string =
  let expr = generator.generateExpression(stmt.expression)
  return generator.getIndent() & expr & "\n"

proc generateForStatement(generator: var NimCodeGenerator, stmt: ForStatement): string =
  var output = ""
  
  if stmt.init.isNone and stmt.condition.isNone and stmt.increment.isNone:
    output.add(generator.getIndent() & "while true:\n")
  else:
    if stmt.init.isSome:
      output.add(generator.getIndent() & generator.generateExpression(stmt.init.get()) & "\n")
    
    if stmt.condition.isSome:
      output.add(generator.getIndent() & "while " & generator.generateExpression(stmt.condition.get()) & ":\n")
    else:
      output.add(generator.getIndent() & "while true:\n")
  
  generator.indent += 1
  for bodyStmt in stmt.body:
    output.add(generator.generateStatement(bodyStmt))
  
  if stmt.increment.isSome:
    output.add(generator.getIndent() & generator.generateExpression(stmt.increment.get()) & "\n")
  
  generator.indent -= 1
  
  return output

proc generateWhileStatement(generator: var NimCodeGenerator, stmt: WhileStatement): string =
  var output = generator.getIndent() & "while " & generator.generateExpression(stmt.condition) & ":\n"
  
  generator.indent += 1
  for bodyStmt in stmt.body:
    output.add(generator.generateStatement(bodyStmt))
  generator.indent -= 1
  
  return output

proc generateIfStatement(generator: var NimCodeGenerator, stmt: IfStatement): string =
  var output = generator.getIndent() & "if " & generator.generateExpression(stmt.condition) & ":\n"
  
  generator.indent += 1
  for thenStmt in stmt.thenBranch:
    output.add(generator.generateStatement(thenStmt))
  generator.indent -= 1
  
  if stmt.elseBranch.isSome and stmt.elseBranch.get().len > 0:
    output.add(generator.getIndent() & "else:\n")
    generator.indent += 1
    for elseStmt in stmt.elseBranch.get():
      output.add(generator.generateStatement(elseStmt))
    generator.indent -= 1
  
  return output

proc generateStatement(generator: var NimCodeGenerator, stmt: Statement): string =
  case stmt.nodeType:
  of "AssignmentStatement":
    return generator.generateAssignmentStatement(cast[AssignmentStatement](stmt))
  of "ReturnStatement":
    return generator.generateReturnStatement(cast[ReturnStatement](stmt))
  of "VariableDeclaration":
    return generator.generateVariableDeclaration(cast[VariableDeclaration](stmt))
  of "ExpressionStatement":
    return generator.generateExpressionStatement(cast[ExpressionStatement](stmt))
  of "ForStatement":
    return generator.generateForStatement(cast[ForStatement](stmt))
  of "WhileStatement":
    return generator.generateWhileStatement(cast[WhileStatement](stmt))
  of "IfStatement":
    return generator.generateIfStatement(cast[IfStatement](stmt))
  else:
    raise newException(ValueError, "Unknown statement type: " & stmt.nodeType)

proc hasReturnStatement(statements: seq[Statement]): bool =
  for stmt in statements:
    if stmt.nodeType == "ReturnStatement":
      return true
  return false

proc generateConstructor(generator: var NimCodeGenerator, className: string, constructor: ConstructorDeclaration): string =
  var paramStrings: seq[string] = @[]
  for param in constructor.parameters:
    let paramKey = className & "." & param.name
    let paramType = generator.inferredTypes.getOrDefault(paramKey, "string")
    paramStrings.add(param.name & ": " & paramType)
  let params = paramStrings.join(", ")
  var output = "proc new" & className & "*(" & params & "): " & className & " =\n"
  
  generator.indent += 1
  generator.inConstructor = true
  output.add(generator.getIndent() & "result = " & className & "()\n")
  
  for stmt in constructor.body:
    output.add(generator.generateStatement(stmt))
  
  generator.inConstructor = false
  generator.indent -= 1
  return output

proc generateDefaultConstructor(generator: var NimCodeGenerator, className: string): string =
  var output = "proc new" & className & "*(): " & className & " =\n"
  
  generator.indent += 1
  output.add(generator.getIndent() & "result = " & className & "()\n")
  generator.indent -= 1
  
  return output

proc generateMethod(generator: var NimCodeGenerator, className: string, methodDecl: MethodDeclaration): string =
  var paramStrings: seq[string] = @["self: " & className]
  for param in methodDecl.parameters:
    paramStrings.add(param.name & ": string")
  let params = paramStrings.join(", ")
  
  var output = "proc " & methodDecl.name & "*(" & params & ")"
  
  let hasReturn = methodDecl.body.hasReturnStatement()
  if hasReturn:
    output.add(": string")
  
  output.add(" =\n")
  
  generator.indent += 1
  for stmt in methodDecl.body:
    output.add(generator.generateStatement(stmt))
  generator.indent -= 1
  
  return output

proc generateClassDeclaration(generator: var NimCodeGenerator, node: ClassDeclaration): string =
  var output = "type " & node.name & "* = ref object\n"
  
  if node.constructor.isSome:
    generator.indent += 1
    for param in node.constructor.get().parameters:
      let paramKey = node.name & "." & param.name
      let paramType = generator.inferredTypes.getOrDefault(paramKey, "string")
      output.add(generator.getIndent() & param.name & "*: " & paramType & "\n")
    generator.indent -= 1
  
  output.add("\n")
  
  if node.constructor.isSome:
    output.add(generator.generateConstructor(node.name, node.constructor.get()) & "\n")
  else:
    output.add(generator.generateDefaultConstructor(node.name) & "\n")
  
  for methodDecl in node.methods:
    output.add(generator.generateMethod(node.name, methodDecl) & "\n")
  
  return output

proc generateTypeDeclaration(generator: var NimCodeGenerator, node: TypeDeclaration): string =
  if node.typeKind == "external":
    return "# External type: " & node.name
  else:
    return "type " & node.name & "* = object"

proc generateConstantDeclaration(generator: var NimCodeGenerator, node: ConstantDeclaration): string =
  let value = generator.generateExpression(node.value)
  return "const " & node.name & "* = " & value

proc generateFunctionDeclaration(generator: var NimCodeGenerator, node: FunctionDeclaration): string =
  var paramStrings: seq[string] = @[]
  for param in node.parameters:
    paramStrings.add(param.name & ": string")
  let params = paramStrings.join(", ")
  var output = "proc " & node.name & "*(" & params & ")"
  
  let hasReturn = node.body.hasReturnStatement()
  if hasReturn:
    output.add(": string")
  
  output.add(" =\n")
  
  generator.indent += 1
  for stmt in node.body:
    output.add(generator.generateStatement(stmt))
  generator.indent -= 1
  
  return output

proc generateNode(generator: var NimCodeGenerator, node: ASTNode): string =
  case node.nodeType:
  of "ClassDeclaration":
    return generator.generateClassDeclaration(cast[ClassDeclaration](node))
  of "VariableDeclaration":
    return generator.generateVariableDeclaration(cast[VariableDeclaration](node))
  of "ExpressionStatement":
    return generator.generateExpressionStatement(cast[ExpressionStatement](node))
  of "ForStatement":
    return generator.generateForStatement(cast[ForStatement](node))
  of "WhileStatement":
    return generator.generateWhileStatement(cast[WhileStatement](node))
  of "TypeDeclaration":
    return generator.generateTypeDeclaration(cast[TypeDeclaration](node))
  of "ConstantDeclaration":
    return generator.generateConstantDeclaration(cast[ConstantDeclaration](node))
  of "FunctionDeclaration":
    return generator.generateFunctionDeclaration(cast[FunctionDeclaration](node))
  of "IfStatement":
    return generator.generateIfStatement(cast[IfStatement](node))
  else:
    raise newException(ValueError, "Unknown node type: " & node.nodeType)

proc generate*(generator: var NimCodeGenerator, program: Program): string =
  # First pass: analyze types
  generator.analyzeTypes(program)
  
  var output = ""
  
  output.add("import " & generator.stdlibPrefix & "\n")
  
  let imports = program.body.filter(proc(node: ASTNode): bool = node.nodeType == "ImportDeclaration")
  for importNode in imports:
    output.add(generator.generateImportDeclaration(cast[ImportDeclaration](importNode)) & "\n")
  
  output.add("\n")
  
  let rest = program.body.filter(proc(node: ASTNode): bool = node.nodeType != "ImportDeclaration")
  for node in rest:
    let generated = generator.generateNode(node)
    if generated.strip().len > 0:
      output.add(generated & "\n")
  
  return output