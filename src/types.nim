import options

# Token types enum
type
  TokenType* = enum
    # Keywords
    CLASSE = "CLASSE"
    CONSTRUCTEUR = "CONSTRUCTEUR"
    VARIABLE = "VARIABLE"
    NOUVEAU = "NOUVEAU"
    RETOURNE = "RETOURNE"
    CECI = "CECI"
    IMPORT = "IMPORT"
    FROM = "FROM"
    AS = "AS"
    
    # Operators
    EGAL = "EGAL"
    FLECHE = "FLECHE"
    DOT = "DOT"
    
    # Delimiters
    OUVRIR = "OUVRIR"
    REFERMER = "REFERMER"
    PAREN_OPEN = "PAREN_OPEN"
    PAREN_CLOSE = "PAREN_CLOSE"
    COMMA = "COMMA"
    BRACE_OPEN = "BRACE_OPEN"
    BRACE_CLOSE = "BRACE_CLOSE"
    BRACKET_OPEN = "BRACKET_OPEN"
    BRACKET_CLOSE = "BRACKET_CLOSE"
    SEMICOLON = "SEMICOLON"
    
    # Literals
    IDENTIFIER_TOKEN = "IDENTIFIER"
    STRING = "STRING"
    NUMBER = "NUMBER"
    BOOLEAN = "BOOLEAN"
    
    # Control keywords
    POUR = "POUR"
    TANTQUE = "TANTQUE"
    FONCTION = "FONCTION"
    TYPE = "TYPE"
    EXTERNAL = "EXTERNAL"
    CONSTANT = "CONSTANT"
    SI = "SI"
    SINON = "SINON"
    
    # Nim interop
    AT = "AT"
    NIM = "NIM"
    
    # Extended operators
    COLON = "COLON"
    # Comparison operators
    EGALE = "EGALE"
    DIFFERENT = "DIFFERENT"
    INFERIEUR = "INFERIEUR"
    SUPERIEUR = "SUPERIEUR"
    INFERIEUR_EGAL = "INFERIEUR_EGAL"
    SUPERIEUR_EGAL = "SUPERIEUR_EGAL"
    
    # Miscellaneous
    NEWLINE = "NEWLINE"
    EOF = "EOF"
    PLUS = "PLUS"
    MINUS = "MINUS"

# Token type
type
  Token* = object
    tokenType*: TokenType
    value*: string
    line*: int
    column*: int

# Base AST node
type
  ASTNode* = ref object of RootObj
    nodeType*: string

# Specific AST node types
type
  Parameter* = ref object of ASTNode
    name*: string

  Expression* = ref object of ASTNode

  Statement* = ref object of ASTNode

  Identifier* = ref object of Expression
    name*: string

  StringLiteral* = ref object of Expression
    value*: string

  NumberLiteral* = ref object of Expression
    value*: float

  BooleanLiteral* = ref object of Expression
    value*: bool

  CallExpression* = ref object of Expression
    callee*: Expression
    arguments*: seq[Expression]

  MemberExpression* = ref object of Expression
    obj*: Expression
    property*: string

  BinaryExpression* = ref object of Expression
    left*: Expression
    operator*: string
    right*: Expression

  NewExpression* = ref object of Expression
    callee*: Expression
    arguments*: seq[Expression]

  ArrayLiteral* = ref object of Expression
    elements*: seq[Expression]

  ArrayAccess* = ref object of Expression
    array*: Expression
    index*: Expression

  NimCallExpression* = ref object of Expression
    code*: string

  FunctionExpression* = ref object of Expression
    parameters*: seq[Parameter]
    body*: seq[Statement]

  AssignmentStatement* = ref object of Statement
    left*: Expression
    right*: Expression

  ReturnStatement* = ref object of Statement
    expression*: Expression

  VariableDeclaration* = ref object of Statement
    name*: string
    initializer*: Expression

  ExpressionStatement* = ref object of Statement
    expression*: Expression

  ForStatement* = ref object of Statement
    init*: Option[Expression]
    condition*: Option[Expression]
    increment*: Option[Expression]
    body*: seq[Statement]

  WhileStatement* = ref object of Statement
    condition*: Expression
    body*: seq[Statement]

  IfStatement* = ref object of Statement
    condition*: Expression
    thenBranch*: seq[Statement]
    elseBranch*: Option[seq[Statement]]

  ConstructorDeclaration* = ref object of ASTNode
    parameters*: seq[Parameter]
    body*: seq[Statement]

  MethodDeclaration* = ref object of ASTNode
    name*: string
    parameters*: seq[Parameter]
    body*: seq[Statement]

  ClassDeclaration* = ref object of ASTNode
    name*: string
    methods*: seq[MethodDeclaration]
    constructor*: Option[ConstructorDeclaration]

  ImportDeclaration* = ref object of ASTNode
    module*: string
    alias*: Option[string]
    path*: string

  TypeDeclaration* = ref object of ASTNode
    name*: string
    typeKind*: string  # "external" or "regular"

  ConstantDeclaration* = ref object of ASTNode
    name*: string
    value*: Expression

  FunctionDeclaration* = ref object of ASTNode
    name*: string
    parameters*: seq[Parameter]
    body*: seq[Statement]

  Program* = ref object of ASTNode
    body*: seq[ASTNode]

# Constructor procs
proc newToken*(tokenType: TokenType, value: string, line: int, column: int): Token =
  result = Token(tokenType: tokenType, value: value, line: line, column: column)

proc newIdentifier*(name: string): Identifier =
  result = Identifier(nodeType: "Identifier", name: name)

proc newStringLiteral*(value: string): StringLiteral =
  result = StringLiteral(nodeType: "StringLiteral", value: value)

proc newNumberLiteral*(value: float): NumberLiteral =
  result = NumberLiteral(nodeType: "NumberLiteral", value: value)

proc newBooleanLiteral*(value: bool): BooleanLiteral =
  result = BooleanLiteral(nodeType: "BooleanLiteral", value: value)

proc newParameter*(name: string): Parameter =
  result = Parameter(nodeType: "Parameter", name: name)

proc newProgram*(body: seq[ASTNode]): Program =
  result = Program(nodeType: "Program", body: body)