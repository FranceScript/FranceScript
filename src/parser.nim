import types, options, strutils

type
  Parser* = object
    tokens: seq[Token]
    current: int

proc newParser*(tokens: seq[Token]): Parser =
  result = Parser(tokens: tokens, current: 0)

proc peek(parser: Parser): Token =
  parser.tokens[parser.current]

proc isAtEnd(parser: Parser): bool =
  peek(parser).tokenType == EOF

proc previous(parser: Parser): Token =
  parser.tokens[parser.current - 1]

proc advance(parser: var Parser): Token =
  if not parser.isAtEnd():
    parser.current += 1
  return parser.previous()

proc check(parser: Parser, tokenType: TokenType): bool =
  if parser.isAtEnd(): return false
  return parser.peek().tokenType == tokenType

proc match(parser: var Parser, tokenTypes: varargs[TokenType]): bool =
  for tokenType in tokenTypes:
    if parser.check(tokenType):
      discard parser.advance()
      return true
  return false

proc consume(parser: var Parser, tokenType: TokenType, message: string): Token =
  if parser.check(tokenType):
    return parser.advance()
  
  let current = parser.peek()
  raise newException(ValueError, message & ". Got " & current.value & " at line " & $current.line)

proc skipNewlines(parser: var Parser) =
  while parser.match(NEWLINE):
    discard

proc parseExpression(parser: var Parser): Expression
proc parseStatement(parser: var Parser): Statement
proc parseStatements(parser: var Parser): seq[Statement]
proc parseFunctionExpression(parser: var Parser): FunctionExpression
proc parseNimCall(parser: var Parser): NimCallExpression
proc parseArrayLiteral(parser: var Parser): ArrayLiteral

proc parseArguments(parser: var Parser): seq[Expression] =
  var args: seq[Expression] = @[]
  
  if not parser.check(PAREN_CLOSE):
    args.add(parser.parseExpression())
    
    while parser.match(COMMA):
      args.add(parser.parseExpression())
  
  return args

proc parsePrimary(parser: var Parser): Expression =
  if parser.match(NOUVEAU):
    var callee: Expression = newIdentifier(parser.consume(IDENTIFIER_TOKEN, "Expected class name").value)
    
    while parser.match(DOT):
      let property = parser.consume(IDENTIFIER_TOKEN, "Expected property name").value
      var memberExpr = MemberExpression(nodeType: "MemberExpression")
      memberExpr.obj = callee
      memberExpr.property = property
      callee = memberExpr
    
    discard parser.consume(PAREN_OPEN, "Expected '('")
    let args = parser.parseArguments()
    discard parser.consume(PAREN_CLOSE, "Expected ')'")
    
    var newExpr = NewExpression(nodeType: "NewExpression")
    newExpr.callee = callee
    newExpr.arguments = args
    return newExpr
  
  if parser.match(CECI):
    return newIdentifier("self")
  
  if parser.match(STRING):
    return newStringLiteral(parser.previous().value)
  
  if parser.match(IDENTIFIER_TOKEN):
    return newIdentifier(parser.previous().value)
  
  if parser.match(NUMBER):
    return newNumberLiteral(parseFloat(parser.previous().value))
  
  if parser.match(BOOLEAN):
    return newBooleanLiteral(parser.previous().value == "vrai")
  
  if parser.match(FONCTION):
    return parser.parseFunctionExpression()
  
  if parser.match(AT):
    return parser.parseNimCall()
  
  if parser.match(BRACKET_OPEN):
    return parser.parseArrayLiteral()
  
  if parser.match(PAREN_OPEN):
    let expr = parser.parseExpression()
    discard parser.consume(PAREN_CLOSE, "Expected ')'")
    return expr
  
  let current = parser.peek()
  raise newException(ValueError, "Unexpected token: " & current.value & " at line " & $current.line)

proc parseArrayLiteral(parser: var Parser): ArrayLiteral =
  var elements: seq[Expression] = @[]
  
  if not parser.check(BRACKET_CLOSE):
    elements.add(parser.parseExpression())
    while parser.match(COMMA):
      elements.add(parser.parseExpression())
  
  discard parser.consume(BRACKET_CLOSE, "Expected ']'")
  
  result = ArrayLiteral(nodeType: "ArrayLiteral")
  result.elements = elements

proc parseCall(parser: var Parser): Expression =
  var expr = parser.parsePrimary()
  
  while true:
    if parser.match(FLECHE) or parser.match(DOT):
      let property = parser.consume(IDENTIFIER_TOKEN, "Expected property name").value
      var memberExpr = MemberExpression(nodeType: "MemberExpression")
      memberExpr.obj = expr
      memberExpr.property = property
      expr = memberExpr
      
      if parser.check(PAREN_OPEN):
        discard parser.advance()
        let args = parser.parseArguments()
        discard parser.consume(PAREN_CLOSE, "Expected ')'")
        var callExpr = CallExpression(nodeType: "CallExpression")
        callExpr.callee = expr
        callExpr.arguments = args
        expr = callExpr
    elif parser.check(PAREN_OPEN):
      discard parser.advance()
      let args = parser.parseArguments()
      discard parser.consume(PAREN_CLOSE, "Expected ')'")
      var callExpr = CallExpression(nodeType: "CallExpression")
      callExpr.callee = expr
      callExpr.arguments = args
      expr = callExpr
    elif parser.check(BRACKET_OPEN):
      discard parser.advance()
      let index = parser.parseExpression()
      discard parser.consume(BRACKET_CLOSE, "Expected ']'")
      var arrayAccess = ArrayAccess(nodeType: "ArrayAccess")
      arrayAccess.array = expr
      arrayAccess.index = index
      expr = arrayAccess
    else:
      break
  
  return expr

proc parseComparison(parser: var Parser): Expression =
  var expr = parser.parseCall()
  
  while parser.match(EGALE, DIFFERENT, INFERIEUR, SUPERIEUR, INFERIEUR_EGAL, SUPERIEUR_EGAL):
    let operator = parser.previous().value
    let right = parser.parseCall()
    var binaryExpr = BinaryExpression(nodeType: "BinaryExpression")
    binaryExpr.left = expr
    binaryExpr.operator = operator
    binaryExpr.right = right
    expr = binaryExpr
  
  return expr

proc parseBinary(parser: var Parser): Expression =
  var expr = parser.parseComparison()
  
  while parser.match(PLUS, MINUS):
    let operator = parser.previous().value
    let right = parser.parseComparison()
    var binaryExpr = BinaryExpression(nodeType: "BinaryExpression")
    binaryExpr.left = expr
    binaryExpr.operator = operator
    binaryExpr.right = right
    expr = binaryExpr
  
  return expr

proc parseExpression(parser: var Parser): Expression =
  return parser.parseBinary()

proc parseFunctionExpression(parser: var Parser): FunctionExpression =
  discard parser.consume(PAREN_OPEN, "Expected '('")
  
  var parameters: seq[Parameter] = @[]
  if not parser.check(PAREN_CLOSE):
    parameters.add(newParameter(parser.consume(IDENTIFIER_TOKEN, "Expected parameter name").value))
    
    while parser.match(COMMA):
      parameters.add(newParameter(parser.consume(IDENTIFIER_TOKEN, "Expected parameter name").value))
  
  discard parser.consume(PAREN_CLOSE, "Expected ')'")
  discard parser.consume(OUVRIR, "Expected 'ouvrir'")
  parser.skipNewlines()
  
  let body = parser.parseStatements()
  
  discard parser.consume(REFERMER, "Expected 'refermer'")
  
  result = FunctionExpression(nodeType: "FunctionExpression")
  result.parameters = parameters
  result.body = body

proc parseNimCall(parser: var Parser): NimCallExpression =
  discard parser.consume(NIM, "Expected 'nim'")
  discard parser.consume(PAREN_OPEN, "Expected '('")
  
  var nimCode = ""
  var parenDepth = 1
  var needSpace = false
  
  while not parser.isAtEnd() and parenDepth > 0:
    let token = parser.advance()
    
    if needSpace and token.tokenType != PAREN_CLOSE and token.tokenType != COMMA:
      nimCode.add(' ')
    
    case token.tokenType:
    of PAREN_OPEN:
      parenDepth += 1
      nimCode.add(token.value)
      needSpace = false
    of PAREN_CLOSE:
      parenDepth -= 1
      if parenDepth > 0:
        nimCode.add(token.value)
      needSpace = true
    of STRING:
      nimCode.add("\"" & token.value & "\"")
      needSpace = true
    else:
      nimCode.add(token.value)
      needSpace = (token.tokenType != COMMA)
  
  result = NimCallExpression(nodeType: "NimCallExpression")
  result.code = nimCode.strip()

proc parseReturnStatement(parser: var Parser): ReturnStatement =
  discard parser.consume(RETOURNE, "Expected 'retourne'")
  let expression = parser.parseExpression()
  
  result = ReturnStatement(nodeType: "ReturnStatement")
  result.expression = expression

proc parseVariableDeclaration(parser: var Parser): VariableDeclaration =
  discard parser.consume(VARIABLE, "Expected 'variable'")
  let name = parser.consume(IDENTIFIER_TOKEN, "Expected variable name").value
  discard parser.consume(EGAL, "Expected 'egal'")
  let initializer = parser.parseExpression()
  
  result = VariableDeclaration(nodeType: "VariableDeclaration")
  result.name = name
  result.initializer = initializer

proc parseExpressionStatement(parser: var Parser): ExpressionStatement =
  let expression = parser.parseExpression()
  result = ExpressionStatement(nodeType: "ExpressionStatement")
  result.expression = expression

proc parseForStatement(parser: var Parser): ForStatement =
  discard parser.consume(POUR, "Expected 'pour'")
  discard parser.consume(PAREN_OPEN, "Expected '('")
  
  var init: Option[Expression] = none(Expression)
  if not parser.check(SEMICOLON):
    init = some(parser.parseExpression())
  discard parser.consume(SEMICOLON, "Expected ';'")
  
  var condition: Option[Expression] = none(Expression)
  if not parser.check(SEMICOLON):
    condition = some(parser.parseExpression())
  discard parser.consume(SEMICOLON, "Expected ';'")
  
  var increment: Option[Expression] = none(Expression)
  if not parser.check(PAREN_CLOSE):
    increment = some(parser.parseExpression())
  discard parser.consume(PAREN_CLOSE, "Expected ')'")
  
  var body: seq[Statement]
  if parser.check(BRACE_OPEN):
    discard parser.advance()
    parser.skipNewlines()
    body = parser.parseStatements()
    discard parser.consume(BRACE_CLOSE, "Expected '}'")
  else:
    discard parser.consume(OUVRIR, "Expected 'ouvrir' or '{'")
    parser.skipNewlines()
    body = parser.parseStatements()
    discard parser.consume(REFERMER, "Expected 'refermer'")
  
  result = ForStatement(nodeType: "ForStatement")
  result.init = init
  result.condition = condition
  result.increment = increment
  result.body = body

proc parseWhileStatement(parser: var Parser): WhileStatement =
  discard parser.consume(TANTQUE, "Expected 'tantque'")
  discard parser.consume(PAREN_OPEN, "Expected '('")
  
  let condition = parser.parseExpression()
  
  discard parser.consume(PAREN_CLOSE, "Expected ')'")
  
  var body: seq[Statement]
  if parser.check(BRACE_OPEN):
    discard parser.advance()
    parser.skipNewlines()
    body = parser.parseStatements()
    discard parser.consume(BRACE_CLOSE, "Expected '}'")
  else:
    discard parser.consume(OUVRIR, "Expected 'ouvrir' or '{'")
    parser.skipNewlines()
    body = parser.parseStatements()
    discard parser.consume(REFERMER, "Expected 'refermer'")
  
  result = WhileStatement(nodeType: "WhileStatement")
  result.condition = condition
  result.body = body

proc parseIfStatement(parser: var Parser): IfStatement =
  discard parser.consume(SI, "Expected 'si'")
  discard parser.consume(PAREN_OPEN, "Expected '('")
  
  let condition = parser.parseExpression()
  
  discard parser.consume(PAREN_CLOSE, "Expected ')'")
  discard parser.consume(OUVRIR, "Expected 'ouvrir'")
  parser.skipNewlines()
  
  let thenBranch = parser.parseStatements()
  
  discard parser.consume(REFERMER, "Expected 'refermer'")
  
  var elseBranch: Option[seq[Statement]] = none(seq[Statement])
  if parser.match(SINON):
    discard parser.consume(OUVRIR, "Expected 'ouvrir'")
    parser.skipNewlines()
    elseBranch = some(parser.parseStatements())
    discard parser.consume(REFERMER, "Expected 'refermer'")
  
  result = IfStatement(nodeType: "IfStatement")
  result.condition = condition
  result.thenBranch = thenBranch
  result.elseBranch = elseBranch

proc parseStatement(parser: var Parser): Statement =
  if parser.check(RETOURNE):
    return parser.parseReturnStatement()
  elif parser.check(VARIABLE):
    return parser.parseVariableDeclaration()
  elif parser.check(POUR):
    return parser.parseForStatement()
  elif parser.check(TANTQUE):
    return parser.parseWhileStatement()
  elif parser.check(SI):
    return parser.parseIfStatement()
  else:
    let expr = parser.parseExpression()
    if parser.check(EGAL):
      discard parser.advance()
      let right = parser.parseExpression()
      var assignStmt = AssignmentStatement(nodeType: "AssignmentStatement")
      assignStmt.left = expr
      assignStmt.right = right
      return assignStmt
    else:
      var exprStmt = ExpressionStatement(nodeType: "ExpressionStatement")
      exprStmt.expression = expr
      return exprStmt

proc parseStatements(parser: var Parser): seq[Statement] =
  var statements: seq[Statement] = @[]
  
  while not parser.check(REFERMER) and not parser.check(BRACE_CLOSE) and not parser.isAtEnd():
    parser.skipNewlines()
    if parser.check(REFERMER) or parser.check(BRACE_CLOSE):
      break
    
    statements.add(parser.parseStatement())
    parser.skipNewlines()
  
  return statements

proc parseConstructorDeclaration(parser: var Parser): ConstructorDeclaration =
  discard parser.consume(CONSTRUCTEUR, "Expected 'constructeur'")
  discard parser.consume(PAREN_OPEN, "Expected '('")
  
  var parameters: seq[Parameter] = @[]
  if not parser.check(PAREN_CLOSE):
    parameters.add(newParameter(parser.consume(IDENTIFIER_TOKEN, "Expected parameter name").value))
    
    while parser.match(COMMA):
      parameters.add(newParameter(parser.consume(IDENTIFIER_TOKEN, "Expected parameter name").value))
  
  discard parser.consume(PAREN_CLOSE, "Expected ')'")
  discard parser.consume(OUVRIR, "Expected 'ouvrir'")
  parser.skipNewlines()
  
  let body = parser.parseStatements()
  
  discard parser.consume(REFERMER, "Expected 'refermer'")
  
  result = ConstructorDeclaration(nodeType: "ConstructorDeclaration")
  result.parameters = parameters
  result.body = body

proc parseMethodDeclaration(parser: var Parser): MethodDeclaration =
  let name = parser.consume(IDENTIFIER_TOKEN, "Expected method name").value
  discard parser.consume(PAREN_OPEN, "Expected '('")
  
  var parameters: seq[Parameter] = @[]
  if not parser.check(PAREN_CLOSE):
    parameters.add(newParameter(parser.consume(IDENTIFIER_TOKEN, "Expected parameter name").value))
    
    while parser.match(COMMA):
      parameters.add(newParameter(parser.consume(IDENTIFIER_TOKEN, "Expected parameter name").value))
  
  discard parser.consume(PAREN_CLOSE, "Expected ')'")
  discard parser.consume(OUVRIR, "Expected 'ouvrir'")
  parser.skipNewlines()
  
  let body = parser.parseStatements()
  
  discard parser.consume(REFERMER, "Expected 'refermer'")
  
  result = MethodDeclaration(nodeType: "MethodDeclaration")
  result.name = name
  result.parameters = parameters
  result.body = body

proc parseClassDeclaration(parser: var Parser): ClassDeclaration =
  discard parser.consume(CLASSE, "Expected 'classe'")
  let name = parser.consume(IDENTIFIER_TOKEN, "Expected class name").value
  discard parser.consume(OUVRIR, "Expected 'ouvrir'")
  parser.skipNewlines()
  
  var methods: seq[MethodDeclaration] = @[]
  var constructor: Option[ConstructorDeclaration] = none(ConstructorDeclaration)
  
  while not parser.check(REFERMER) and not parser.isAtEnd():
    parser.skipNewlines()
    
    if parser.check(CONSTRUCTEUR):
      constructor = some(parser.parseConstructorDeclaration())
    elif parser.check(IDENTIFIER_TOKEN):
      methods.add(parser.parseMethodDeclaration())
    else:
      discard parser.advance()
    
    parser.skipNewlines()
  
  discard parser.consume(REFERMER, "Expected 'refermer'")
  
  result = ClassDeclaration(nodeType: "ClassDeclaration")
  result.name = name
  result.methods = methods
  result.constructor = constructor

proc parseImportDeclaration(parser: var Parser): ImportDeclaration =
  discard parser.consume(IMPORT, "Expected 'import'")
  let module = parser.consume(IDENTIFIER_TOKEN, "Expected module name").value
  
  var alias: Option[string] = none(string)
  if parser.match(AS):
    alias = some(parser.consume(IDENTIFIER_TOKEN, "Expected alias name").value)
  
  discard parser.consume(FROM, "Expected 'from'")
  let path = parser.consume(STRING, "Expected path string").value
  
  result = ImportDeclaration(nodeType: "ImportDeclaration")
  result.module = module
  result.alias = alias
  result.path = path

proc parseTypeDeclaration(parser: var Parser): TypeDeclaration =
  discard parser.consume(TYPE, "Expected 'type'")
  let name = parser.consume(IDENTIFIER_TOKEN, "Expected type name").value
  discard parser.consume(EGAL, "Expected 'egal'")
  
  var typeKind = "regular"
  if parser.match(EXTERNAL):
    typeKind = "external"
  
  result = TypeDeclaration(nodeType: "TypeDeclaration")
  result.name = name
  result.typeKind = typeKind

proc parseConstantDeclaration(parser: var Parser): ConstantDeclaration =
  discard parser.consume(CONSTANT, "Expected 'constant'")
  let name = parser.consume(IDENTIFIER_TOKEN, "Expected constant name").value
  discard parser.consume(EGAL, "Expected 'egal'")
  let value = parser.parseExpression()
  
  result = ConstantDeclaration(nodeType: "ConstantDeclaration")
  result.name = name
  result.value = value

proc parseFunctionDeclaration(parser: var Parser): FunctionDeclaration =
  discard parser.consume(FONCTION, "Expected 'fonction'")
  let name = parser.consume(IDENTIFIER_TOKEN, "Expected function name").value
  discard parser.consume(PAREN_OPEN, "Expected '('")
  
  var parameters: seq[Parameter] = @[]
  if not parser.check(PAREN_CLOSE):
    parameters.add(newParameter(parser.consume(IDENTIFIER_TOKEN, "Expected parameter name").value))
    
    while parser.match(COMMA):
      parameters.add(newParameter(parser.consume(IDENTIFIER_TOKEN, "Expected parameter name").value))
  
  discard parser.consume(PAREN_CLOSE, "Expected ')'")
  discard parser.consume(OUVRIR, "Expected 'ouvrir'")
  parser.skipNewlines()
  
  let body = parser.parseStatements()
  
  discard parser.consume(REFERMER, "Expected 'refermer'")
  
  result = FunctionDeclaration(nodeType: "FunctionDeclaration")
  result.name = name
  result.parameters = parameters
  result.body = body

proc parse*(parser: var Parser): Program =
  var body: seq[ASTNode] = @[]
  
  while not parser.isAtEnd():
    parser.skipNewlines()
    if parser.isAtEnd():
      break
    
    if parser.check(IMPORT):
      body.add(parser.parseImportDeclaration())
    elif parser.check(CLASSE):
      body.add(parser.parseClassDeclaration())
    elif parser.check(VARIABLE):
      body.add(parser.parseVariableDeclaration())
    elif parser.check(TYPE):
      body.add(parser.parseTypeDeclaration())
    elif parser.check(CONSTANT):
      body.add(parser.parseConstantDeclaration())
    elif parser.check(FONCTION):
      body.add(parser.parseFunctionDeclaration())
    elif parser.check(SI):
      body.add(parser.parseIfStatement())
    elif parser.check(POUR):
      body.add(parser.parseForStatement())
    elif parser.check(TANTQUE):
      body.add(parser.parseWhileStatement())
    else:
      body.add(parser.parseExpressionStatement())
    
    parser.skipNewlines()
  
  return newProgram(body)