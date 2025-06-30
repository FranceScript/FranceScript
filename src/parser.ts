import { Token, TokenType, Program, ClassDeclaration, MethodDeclaration, ConstructorDeclaration, Statement, Expression, AssignmentStatement, ReturnStatement, VariableDeclaration, ExpressionStatement, CallExpression, MemberExpression, Identifier, StringLiteral, BinaryExpression, NewExpression, Parameter, ImportDeclaration, NumberLiteral, BooleanLiteral, FunctionExpression, ForStatement, WhileStatement, ArrayLiteral, ArrayAccess, NimCallExpression, TypeDeclaration, ConstantDeclaration, FunctionDeclaration, IfStatement } from './types';

export class Parser {
  private tokens: Token[];
  private current: number = 0;

  constructor(tokens: Token[]) {
    this.tokens = tokens;
  }

  parse(): Program {
    const body: (ImportDeclaration | ClassDeclaration | VariableDeclaration | ExpressionStatement | ForStatement | WhileStatement | TypeDeclaration | ConstantDeclaration | FunctionDeclaration | IfStatement)[] = [];

    while (!this.isAtEnd()) {
      this.skipNewlines();
      if (this.isAtEnd()) break;

      if (this.check(TokenType.IMPORT)) {
        body.push(this.parseImportDeclaration());
      } else if (this.check(TokenType.CLASSE)) {
        body.push(this.parseClassDeclaration());
      } else if (this.check(TokenType.VARIABLE)) {
        body.push(this.parseVariableDeclaration());
      } else if (this.check(TokenType.TYPE)) {
        body.push(this.parseTypeDeclaration());
      } else if (this.check(TokenType.CONSTANT)) {
        body.push(this.parseConstantDeclaration());
      } else if (this.check(TokenType.FONCTION)) {
        body.push(this.parseFunctionDeclaration());
      } else if (this.check(TokenType.SI)) {
        body.push(this.parseIfStatement());
      } else if (this.check(TokenType.POUR)) {
        body.push(this.parseForStatement());
      } else if (this.check(TokenType.TANTQUE)) {
        body.push(this.parseWhileStatement());
      } else {
        body.push(this.parseExpressionStatement());
      }
      
      this.skipNewlines();
    }

    return {
      type: 'Program',
      body
    };
  }

  private parseImportDeclaration(): ImportDeclaration {
    this.consume(TokenType.IMPORT, "Expected 'import'");
    const module = this.consume(TokenType.IDENTIFIER, "Expected module name").value;
    
    let alias: string | undefined;
    if (this.match(TokenType.AS)) {
      alias = this.consume(TokenType.IDENTIFIER, "Expected alias name").value;
    }
    
    this.consume(TokenType.FROM, "Expected 'from'");
    const path = this.consume(TokenType.STRING, "Expected path string").value;
    
    return {
      type: 'ImportDeclaration',
      module,
      alias,
      path
    };
  }

  private parseClassDeclaration(): ClassDeclaration {
    this.consume(TokenType.CLASSE, "Expected 'classe'");
    const name = this.consume(TokenType.IDENTIFIER, "Expected class name").value;
    this.consume(TokenType.OUVRIR, "Expected 'ouvrir'");
    this.skipNewlines();

    const methods: MethodDeclaration[] = [];
    let constructor: ConstructorDeclaration | undefined;

    while (!this.check(TokenType.REFERMER) && !this.isAtEnd()) {
      this.skipNewlines();
      
      if (this.check(TokenType.CONSTRUCTEUR)) {
        constructor = this.parseConstructorDeclaration();
      } else if (this.check(TokenType.IDENTIFIER)) {
        methods.push(this.parseMethodDeclaration());
      } else {
        this.advance();
      }
      
      this.skipNewlines();
    }

    this.consume(TokenType.REFERMER, "Expected 'refermer'");

    return {
      type: 'ClassDeclaration',
      name,
      methods,
      constructor
    };
  }

  private parseConstructorDeclaration(): ConstructorDeclaration {
    this.consume(TokenType.CONSTRUCTEUR, "Expected 'constructeur'");
    this.consume(TokenType.PAREN_OPEN, "Expected '('");
    
    const parameters: Parameter[] = [];
    if (!this.check(TokenType.PAREN_CLOSE)) {
      parameters.push({
        type: 'Parameter',
        name: this.consume(TokenType.IDENTIFIER, "Expected parameter name").value
      });
      
      // Handle comma-separated parameters
      while (this.match(TokenType.COMMA)) {
        parameters.push({
          type: 'Parameter',
          name: this.consume(TokenType.IDENTIFIER, "Expected parameter name").value
        });
      }
    }
    
    this.consume(TokenType.PAREN_CLOSE, "Expected ')'");
    this.consume(TokenType.OUVRIR, "Expected 'ouvrir'");
    this.skipNewlines();

    const body = this.parseStatements();

    this.consume(TokenType.REFERMER, "Expected 'refermer'");

    return {
      type: 'ConstructorDeclaration',
      parameters,
      body
    };
  }

  private parseMethodDeclaration(): MethodDeclaration {
    const name = this.consume(TokenType.IDENTIFIER, "Expected method name").value;
    this.consume(TokenType.PAREN_OPEN, "Expected '('");
    
    const parameters: Parameter[] = [];
    if (!this.check(TokenType.PAREN_CLOSE)) {
      parameters.push({
        type: 'Parameter',
        name: this.consume(TokenType.IDENTIFIER, "Expected parameter name").value
      });
      
      // Handle comma-separated parameters
      while (this.match(TokenType.COMMA)) {
        parameters.push({
          type: 'Parameter',
          name: this.consume(TokenType.IDENTIFIER, "Expected parameter name").value
        });
      }
    }
    
    this.consume(TokenType.PAREN_CLOSE, "Expected ')'");
    this.consume(TokenType.OUVRIR, "Expected 'ouvrir'");
    this.skipNewlines();

    const body = this.parseStatements();

    this.consume(TokenType.REFERMER, "Expected 'refermer'");

    return {
      type: 'MethodDeclaration',
      name,
      parameters,
      body
    };
  }

  private parseStatements(): Statement[] {
    const statements: Statement[] = [];

    while (!this.check(TokenType.REFERMER) && !this.check(TokenType.BRACE_CLOSE) && !this.isAtEnd()) {
      this.skipNewlines();
      if (this.check(TokenType.REFERMER) || this.check(TokenType.BRACE_CLOSE)) break;

      if (this.check(TokenType.RETOURNE)) {
        statements.push(this.parseReturnStatement());
      } else if (this.check(TokenType.VARIABLE)) {
        statements.push(this.parseVariableDeclaration());
      } else if (this.check(TokenType.POUR)) {
        statements.push(this.parseForStatement());
      } else if (this.check(TokenType.TANTQUE)) {
        statements.push(this.parseWhileStatement());
      } else if (this.check(TokenType.SI)) {
        statements.push(this.parseIfStatement());
      } else {
        const expr = this.parseExpression();
        if (this.check(TokenType.EGAL)) {
          this.advance();
          const right = this.parseExpression();
          statements.push({
            type: 'AssignmentStatement',
            left: expr,
            right
          } as AssignmentStatement);
        } else {
          statements.push({
            type: 'ExpressionStatement',
            expression: expr
          } as ExpressionStatement);
        }
      }
      
      this.skipNewlines();
    }

    return statements;
  }

  private parseReturnStatement(): ReturnStatement {
    this.consume(TokenType.RETOURNE, "Expected 'retourne'");
    const expression = this.parseExpression();
    
    return {
      type: 'ReturnStatement',
      expression
    };
  }

  private parseVariableDeclaration(): VariableDeclaration {
    this.consume(TokenType.VARIABLE, "Expected 'variable'");
    const name = this.consume(TokenType.IDENTIFIER, "Expected variable name").value;
    this.consume(TokenType.EGAL, "Expected 'egal'");
    const initializer = this.parseExpression();

    return {
      type: 'VariableDeclaration',
      name,
      initializer
    };
  }

  private parseExpressionStatement(): ExpressionStatement {
    const expression = this.parseExpression();
    return {
      type: 'ExpressionStatement',
      expression
    };
  }

  private parseExpression(): Expression {
    return this.parseBinary();
  }

  private parseBinary(): Expression {
    let expr = this.parseComparison();

    while (this.match(TokenType.PLUS, TokenType.MINUS)) {
      const operator = this.previous().value;
      const right = this.parseComparison();
      expr = {
        type: 'BinaryExpression',
        left: expr,
        operator,
        right
      } as BinaryExpression;
    }

    return expr;
  }

  private parseComparison(): Expression {
    let expr = this.parseCall();

    while (this.match(TokenType.EGALE, TokenType.DIFFERENT, TokenType.INFERIEUR, TokenType.SUPERIEUR, TokenType.INFERIEUR_EGAL, TokenType.SUPERIEUR_EGAL)) {
      const operator = this.previous().value;
      const right = this.parseCall();
      expr = {
        type: 'BinaryExpression',
        left: expr,
        operator,
        right
      } as BinaryExpression;
    }

    return expr;
  }

  private parseCall(): Expression {
    let expr = this.parsePrimary();

    while (true) {
      if (this.match(TokenType.FLECHE) || this.match(TokenType.DOT)) {
        const property = this.consume(TokenType.IDENTIFIER, "Expected property name").value;
        expr = {
          type: 'MemberExpression',
          object: expr,
          property
        } as MemberExpression;
        
        // Check if this is a method call (has parentheses)
        if (this.check(TokenType.PAREN_OPEN)) {
          this.advance();
          const args = this.parseArguments();
          this.consume(TokenType.PAREN_CLOSE, "Expected ')'");
          expr = {
            type: 'CallExpression',
            callee: expr,
            arguments: args
          } as CallExpression;
        }
      } else if (this.check(TokenType.PAREN_OPEN)) {
        this.advance();
        const args = this.parseArguments();
        this.consume(TokenType.PAREN_CLOSE, "Expected ')'");
        expr = {
          type: 'CallExpression',
          callee: expr,
          arguments: args
        } as CallExpression;
      } else if (this.check(TokenType.BRACKET_OPEN)) {
        this.advance();
        const index = this.parseExpression();
        this.consume(TokenType.BRACKET_CLOSE, "Expected ']'");
        expr = {
          type: 'ArrayAccess',
          array: expr,
          index
        } as ArrayAccess;
      } else {
        break;
      }
    }

    return expr;
  }

  private parseArguments(): Expression[] {
    const args: Expression[] = [];
    
    if (!this.check(TokenType.PAREN_CLOSE)) {
      args.push(this.parseExpression());
      
      // Handle comma-separated arguments
      while (this.match(TokenType.COMMA)) {
        args.push(this.parseExpression());
      }
    }

    return args;
  }

  private parsePrimary(): Expression {
    if (this.match(TokenType.NOUVEAU)) {
      let callee: Expression = {
        type: 'Identifier',
        name: this.consume(TokenType.IDENTIFIER, "Expected class name").value
      } as Identifier;
      
      while (this.match(TokenType.DOT)) {
        const property = this.consume(TokenType.IDENTIFIER, "Expected property name").value;
        callee = {
          type: 'MemberExpression',
          object: callee,
          property
        } as MemberExpression;
      }
      
      this.consume(TokenType.PAREN_OPEN, "Expected '('");
      const args = this.parseArguments();
      this.consume(TokenType.PAREN_CLOSE, "Expected ')'");
      
      return {
        type: 'NewExpression',
        callee,
        arguments: args
      } as NewExpression;
    }

    if (this.match(TokenType.CECI)) {
      return {
        type: 'Identifier',
        name: 'self'
      } as Identifier;
    }

    if (this.match(TokenType.STRING)) {
      return {
        type: 'StringLiteral',
        value: this.previous().value
      } as StringLiteral;
    }

    if (this.match(TokenType.IDENTIFIER)) {
      return {
        type: 'Identifier',
        name: this.previous().value
      } as Identifier;
    }

    if (this.match(TokenType.NUMBER)) {
      return {
        type: 'NumberLiteral',
        value: parseFloat(this.previous().value)
      } as NumberLiteral;
    }

    if (this.match(TokenType.BOOLEAN)) {
      return {
        type: 'BooleanLiteral',
        value: this.previous().value === 'vrai'
      } as BooleanLiteral;
    }

    if (this.match(TokenType.FONCTION)) {
      return this.parseFunctionExpression();
    }

    if (this.match(TokenType.AT)) {
      return this.parseNimCall();
    }

    if (this.match(TokenType.BRACKET_OPEN)) {
      return this.parseArrayLiteral();
    }

    if (this.match(TokenType.PAREN_OPEN)) {
      const expr = this.parseExpression();
      this.consume(TokenType.PAREN_CLOSE, "Expected ')'");
      return expr;
    }

    throw new Error(`Unexpected token: ${this.peek().value} at line ${this.peek().line}`);
  }

  private parseArrayLiteral(): ArrayLiteral {
    const elements: Expression[] = [];
    
    if (!this.check(TokenType.BRACKET_CLOSE)) {
      do {
        elements.push(this.parseExpression());
      } while (this.match(TokenType.COMMA));
    }
    
    this.consume(TokenType.BRACKET_CLOSE, "Expected ']'");
    
    return {
      type: 'ArrayLiteral',
      elements
    } as ArrayLiteral;
  }

  private match(...types: TokenType[]): boolean {
    for (const type of types) {
      if (this.check(type)) {
        this.advance();
        return true;
      }
    }
    return false;
  }

  private check(type: TokenType): boolean {
    if (this.isAtEnd()) return false;
    return this.peek().type === type;
  }

  private advance(): Token {
    if (!this.isAtEnd()) this.current++;
    return this.previous();
  }

  private isAtEnd(): boolean {
    return this.peek().type === TokenType.EOF;
  }

  private peek(): Token {
    return this.tokens[this.current];
  }

  private previous(): Token {
    return this.tokens[this.current - 1];
  }

  private consume(type: TokenType, message: string): Token {
    if (this.check(type)) return this.advance();
    throw new Error(`${message}. Got ${this.peek().value} at line ${this.peek().line}`);
  }

  private skipNewlines(): void {
    while (this.match(TokenType.NEWLINE)) {
      // Skip newlines
    }
  }

  private parseForStatement(): ForStatement {
    this.consume(TokenType.POUR, "Expected 'pour'");
    this.consume(TokenType.PAREN_OPEN, "Expected '('");
    
    let init: Expression | undefined;
    if (!this.check(TokenType.SEMICOLON)) {
      init = this.parseExpression();
    }
    this.consume(TokenType.SEMICOLON, "Expected ';'");
    
    let condition: Expression | undefined;
    if (!this.check(TokenType.SEMICOLON)) {
      condition = this.parseExpression();
    }
    this.consume(TokenType.SEMICOLON, "Expected ';'");
    
    let increment: Expression | undefined;
    if (!this.check(TokenType.PAREN_CLOSE)) {
      increment = this.parseExpression();
    }
    this.consume(TokenType.PAREN_CLOSE, "Expected ')'");
    
    if (this.check(TokenType.BRACE_OPEN)) {
      this.advance();
      this.skipNewlines();
      const body = this.parseStatements();
      this.consume(TokenType.BRACE_CLOSE, "Expected '}'");
      return {
        type: 'ForStatement',
        init,
        condition,
        increment,
        body
      };
    } else {
      this.consume(TokenType.OUVRIR, "Expected 'ouvrir' or '{'");
      this.skipNewlines();
      const body = this.parseStatements();
      this.consume(TokenType.REFERMER, "Expected 'refermer'");
      return {
        type: 'ForStatement',
        init,
        condition,
        increment,
        body
      };
    }
  }

  private parseWhileStatement(): WhileStatement {
    this.consume(TokenType.TANTQUE, "Expected 'tantque'");
    this.consume(TokenType.PAREN_OPEN, "Expected '('");
    
    const condition = this.parseExpression();
    
    this.consume(TokenType.PAREN_CLOSE, "Expected ')'");
    
    if (this.check(TokenType.BRACE_OPEN)) {
      this.advance();
      this.skipNewlines();
      const body = this.parseStatements();
      this.consume(TokenType.BRACE_CLOSE, "Expected '}'");
      return {
        type: 'WhileStatement',
        condition,
        body
      };
    } else {
      this.consume(TokenType.OUVRIR, "Expected 'ouvrir' or '{'");
      this.skipNewlines();
      const body = this.parseStatements();
      this.consume(TokenType.REFERMER, "Expected 'refermer'");
      return {
        type: 'WhileStatement',
        condition,
        body
      };
    }
  }

  private parseFunctionExpression(): FunctionExpression {
    this.consume(TokenType.PAREN_OPEN, "Expected '('");
    
    const parameters: Parameter[] = [];
    if (!this.check(TokenType.PAREN_CLOSE)) {
      parameters.push({
        type: 'Parameter',
        name: this.consume(TokenType.IDENTIFIER, "Expected parameter name").value
      });
      
      while (this.match(TokenType.COMMA)) {
        parameters.push({
          type: 'Parameter',
          name: this.consume(TokenType.IDENTIFIER, "Expected parameter name").value
        });
      }
    }
    
    this.consume(TokenType.PAREN_CLOSE, "Expected ')'");
    this.consume(TokenType.OUVRIR, "Expected 'ouvrir'");
    this.skipNewlines();

    const body = this.parseStatements();

    this.consume(TokenType.REFERMER, "Expected 'refermer'");

    return {
      type: 'FunctionExpression',
      parameters,
      body
    } as FunctionExpression;
  }

  private parseNimCall(): NimCallExpression {
    this.consume(TokenType.NIM, "Expected 'nim'");
    this.consume(TokenType.PAREN_OPEN, "Expected '('");
    
    let nimCode = '';
    let parenDepth = 1;
    let needSpace = false;
    
    while (!this.isAtEnd() && parenDepth > 0) {
      const token = this.advance();
      
      if (needSpace && token.type !== TokenType.PAREN_CLOSE && token.type !== TokenType.COMMA) {
        nimCode += ' ';
      }
      
      if (token.type === TokenType.PAREN_OPEN) {
        parenDepth++;
        nimCode += token.value;
        needSpace = false;
      } else if (token.type === TokenType.PAREN_CLOSE) {
        parenDepth--;
        if (parenDepth > 0) {
          nimCode += token.value;
        }
        needSpace = true;
      } else if (token.type === TokenType.STRING) {
        nimCode += '"' + token.value + '"';
        needSpace = true;
      } else {
        nimCode += token.value;
        needSpace = (token.type !== TokenType.COMMA);
      }
    }
    
    return {
      type: 'NimCallExpression',
      code: nimCode.trim()
    } as NimCallExpression;
  }

  private parseTypeDeclaration(): TypeDeclaration {
    this.consume(TokenType.TYPE, "Expected 'type'");
    const name = this.consume(TokenType.IDENTIFIER, "Expected type name").value;
    this.consume(TokenType.EGAL, "Expected 'egal'");
    
    let typeKind: 'external' | 'regular' = 'regular';
    if (this.match(TokenType.EXTERNAL)) {
      typeKind = 'external';
    }
    
    return {
      type: 'TypeDeclaration',
      name,
      typeKind
    } as TypeDeclaration;
  }

  private parseConstantDeclaration(): ConstantDeclaration {
    this.consume(TokenType.CONSTANT, "Expected 'constant'");
    const name = this.consume(TokenType.IDENTIFIER, "Expected constant name").value;
    this.consume(TokenType.EGAL, "Expected 'egal'");
    const value = this.parseExpression();
    
    return {
      type: 'ConstantDeclaration',
      name,
      value
    } as ConstantDeclaration;
  }

  private parseFunctionDeclaration(): FunctionDeclaration {
    this.consume(TokenType.FONCTION, "Expected 'fonction'");
    const name = this.consume(TokenType.IDENTIFIER, "Expected function name").value;
    this.consume(TokenType.PAREN_OPEN, "Expected '('");
    
    const parameters: Parameter[] = [];
    if (!this.check(TokenType.PAREN_CLOSE)) {
      parameters.push({
        type: 'Parameter',
        name: this.consume(TokenType.IDENTIFIER, "Expected parameter name").value
      });
      
      while (this.match(TokenType.COMMA)) {
        parameters.push({
          type: 'Parameter',
          name: this.consume(TokenType.IDENTIFIER, "Expected parameter name").value
        });
      }
    }
    
    this.consume(TokenType.PAREN_CLOSE, "Expected ')'")
    this.consume(TokenType.OUVRIR, "Expected 'ouvrir'");
    this.skipNewlines();

    const body = this.parseStatements();

    this.consume(TokenType.REFERMER, "Expected 'refermer'");

    return {
      type: 'FunctionDeclaration',
      name,
      parameters,
      body
    } as FunctionDeclaration;
  }

  private parseIfStatement(): IfStatement {
    this.consume(TokenType.SI, "Expected 'si'");
    this.consume(TokenType.PAREN_OPEN, "Expected '('");
    
    const condition = this.parseExpression();
    
    this.consume(TokenType.PAREN_CLOSE, "Expected ')'");
    this.consume(TokenType.OUVRIR, "Expected 'ouvrir'");
    this.skipNewlines();

    const thenBranch = this.parseStatements();

    this.consume(TokenType.REFERMER, "Expected 'refermer'");
    
    let elseBranch: Statement[] | undefined;
    if (this.match(TokenType.SINON)) {
      this.consume(TokenType.OUVRIR, "Expected 'ouvrir'");
      this.skipNewlines();
      elseBranch = this.parseStatements();
      this.consume(TokenType.REFERMER, "Expected 'refermer'");
    }

    return {
      type: 'IfStatement',
      condition,
      thenBranch,
      elseBranch
    } as IfStatement;
  }
}