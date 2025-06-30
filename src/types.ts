export enum TokenType {
  // Keywords
  CLASSE = 'CLASSE',
  CONSTRUCTEUR = 'CONSTRUCTEUR',
  VARIABLE = 'VARIABLE',
  NOUVEAU = 'NOUVEAU',
  RETOURNE = 'RETOURNE',
  CECI = 'CECI',
  IMPORT = 'IMPORT',
  FROM = 'FROM',
  AS = 'AS',
  
  // Operators
  EGAL = 'EGAL',
  FLECHE = 'FLECHE',
  DOT = 'DOT',
  
  // Delimiters
  OUVRIR = 'OUVRIR',
  REFERMER = 'REFERMER',
  PAREN_OPEN = 'PAREN_OPEN',
  PAREN_CLOSE = 'PAREN_CLOSE',
  COMMA = 'COMMA',
  BRACE_OPEN = 'BRACE_OPEN',
  BRACE_CLOSE = 'BRACE_CLOSE',
  BRACKET_OPEN = 'BRACKET_OPEN',
  BRACKET_CLOSE = 'BRACKET_CLOSE',
  SEMICOLON = 'SEMICOLON',
  
  // Literals
  IDENTIFIER = 'IDENTIFIER',
  STRING = 'STRING',
  NUMBER = 'NUMBER',
  BOOLEAN = 'BOOLEAN',
  
  // Control keywords
  POUR = 'POUR',
  TANTQUE = 'TANTQUE',
  FONCTION = 'FONCTION',
  TYPE = 'TYPE',
  EXTERNAL = 'EXTERNAL',
  CONSTANT = 'CONSTANT',
  SI = 'SI',
  SINON = 'SINON',
  
  // Nim interop
  AT = 'AT',
  NIM = 'NIM',
  
  // Extended operators
  COLON = 'COLON',
  // Comparison operators
  EGALE = 'EGALE',
  DIFFERENT = 'DIFFERENT',
  INFERIEUR = 'INFERIEUR',
  SUPERIEUR = 'SUPERIEUR',
  INFERIEUR_EGAL = 'INFERIEUR_EGAL',
  SUPERIEUR_EGAL = 'SUPERIEUR_EGAL',
  
  // Miscellaneous
  NEWLINE = 'NEWLINE',
  EOF = 'EOF',
  PLUS = 'PLUS',
  MINUS = 'MINUS'
}

export interface Token {
  type: TokenType;
  value: string;
  line: number;
  column: number;
}

export interface ASTNode {
  type: string;
}

export interface ClassDeclaration extends ASTNode {
  type: 'ClassDeclaration';
  name: string;
  methods: MethodDeclaration[];
  constructor?: ConstructorDeclaration;
}

export interface ConstructorDeclaration extends ASTNode {
  type: 'ConstructorDeclaration';
  parameters: Parameter[];
  body: Statement[];
}

export interface MethodDeclaration extends ASTNode {
  type: 'MethodDeclaration';
  name: string;
  parameters: Parameter[];
  body: Statement[];
}

export interface Parameter extends ASTNode {
  type: 'Parameter';
  name: string;
}

export interface Statement extends ASTNode {}

export interface AssignmentStatement extends Statement {
  type: 'AssignmentStatement';
  left: Expression;
  right: Expression;
}

export interface ReturnStatement extends Statement {
  type: 'ReturnStatement';
  expression: Expression;
}

export interface VariableDeclaration extends Statement {
  type: 'VariableDeclaration';
  name: string;
  initializer: Expression;
}

export interface ExpressionStatement extends Statement {
  type: 'ExpressionStatement';
  expression: Expression;
}

export interface Expression extends ASTNode {}

export interface CallExpression extends Expression {
  type: 'CallExpression';
  callee: Expression;
  arguments: Expression[];
}

export interface MemberExpression extends Expression {
  type: 'MemberExpression';
  object: Expression;
  property: string;
}

export interface Identifier extends Expression {
  type: 'Identifier';
  name: string;
}

export interface StringLiteral extends Expression {
  type: 'StringLiteral';
  value: string;
}

export interface NumberLiteral extends Expression {
  type: 'NumberLiteral';
  value: number;
}

export interface BooleanLiteral extends Expression {
  type: 'BooleanLiteral';
  value: boolean;
}

export interface FunctionExpression extends Expression {
  type: 'FunctionExpression';
  parameters: Parameter[];
  body: Statement[];
}

export interface BinaryExpression extends Expression {
  type: 'BinaryExpression';
  left: Expression;
  operator: string;
  right: Expression;
}

export interface NewExpression extends Expression {
  type: 'NewExpression';
  callee: Expression;
  arguments: Expression[];
}

export interface ArrayLiteral extends Expression {
  type: 'ArrayLiteral';
  elements: Expression[];
}

export interface ArrayAccess extends Expression {
  type: 'ArrayAccess';
  array: Expression;
  index: Expression;
}

export interface NimCallExpression extends Expression {
  type: 'NimCallExpression';
  code: string;
}

export interface TypeDeclaration extends ASTNode {
  type: 'TypeDeclaration';
  name: string;
  typeKind: 'external' | 'regular';
}

export interface ConstantDeclaration extends ASTNode {
  type: 'ConstantDeclaration';
  name: string;
  value: Expression;
}

export interface FunctionDeclaration extends ASTNode {
  type: 'FunctionDeclaration';
  name: string;
  parameters: Parameter[];
  body: Statement[];
}

export interface IfStatement extends Statement {
  type: 'IfStatement';
  condition: Expression;
  thenBranch: Statement[];
  elseBranch?: Statement[];
}

export interface ImportDeclaration extends ASTNode {
  type: 'ImportDeclaration';
  module: string;
  alias?: string;
  path: string;
}

export interface ForStatement extends Statement {
  type: 'ForStatement';
  init?: Expression;
  condition?: Expression;
  increment?: Expression;
  body: Statement[];
}

export interface WhileStatement extends Statement {
  type: 'WhileStatement';
  condition: Expression;
  body: Statement[];
}

export interface Program extends ASTNode {
  type: 'Program';
  body: (ImportDeclaration | ClassDeclaration | VariableDeclaration | ExpressionStatement | ForStatement | WhileStatement | TypeDeclaration | ConstantDeclaration | FunctionDeclaration | IfStatement)[];
}