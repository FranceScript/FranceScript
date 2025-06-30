import { Program, ClassDeclaration, MethodDeclaration, ConstructorDeclaration, Statement, Expression, AssignmentStatement, ReturnStatement, VariableDeclaration, ExpressionStatement, CallExpression, MemberExpression, Identifier, StringLiteral, BinaryExpression, NewExpression, ImportDeclaration, ForStatement, WhileStatement, NumberLiteral, BooleanLiteral, FunctionExpression, ArrayLiteral, ArrayAccess, NimCallExpression, TypeDeclaration, ConstantDeclaration, FunctionDeclaration, IfStatement } from './types';

export class NimCodeGenerator {
  private indent: number = 0;
  private inConstructor: boolean = false;
  private stdlibPrefix: string;

  constructor(stdlibPrefix: string = 'std') {
    this.stdlibPrefix = stdlibPrefix;
  }

  generate(program: Program): string {
    let output = '';
    
    output += `import ${this.stdlibPrefix}\n`;
    
    const imports = program.body.filter(node => node.type === 'ImportDeclaration') as ImportDeclaration[];
    for (const importNode of imports) {
      output += this.generateImportDeclaration(importNode) + '\n';
    }
    
    output += '\n';
    
    const rest = program.body.filter(node => node.type !== 'ImportDeclaration');
    for (const node of rest) {
      const generated = this.generateNode(node);
      if (generated.trim()) {
        output += generated + '\n';
      }
    }
    
    return output;
  }

  private generateImportDeclaration(node: ImportDeclaration): string {
    let moduleName = node.path.replace(/\.fr$/, '').replace(/^\.\//, '');
    
    if (node.alias) {
      return `import ${moduleName} as ${node.alias}`;
    } else {
      return `import ${moduleName}`;
    }
  }

  private generateNode(node: any): string {
    switch (node.type) {
      case 'ClassDeclaration':
        return this.generateClassDeclaration(node as ClassDeclaration);
      case 'VariableDeclaration':
        return this.generateVariableDeclaration(node as VariableDeclaration);
      case 'ExpressionStatement':
        return this.generateExpressionStatement(node as ExpressionStatement);
      case 'ForStatement':
        return this.generateForStatement(node as ForStatement);
      case 'WhileStatement':
        return this.generateWhileStatement(node as WhileStatement);
      case 'TypeDeclaration':
        return this.generateTypeDeclaration(node as TypeDeclaration);
      case 'ConstantDeclaration':
        return this.generateConstantDeclaration(node as ConstantDeclaration);
      case 'FunctionDeclaration':
        return this.generateFunctionDeclaration(node as FunctionDeclaration);
      case 'IfStatement':
        return this.generateIfStatement(node as IfStatement);
      default:
        throw new Error(`Unknown node type: ${node.type}`);
    }
  }

  private generateClassDeclaration(node: ClassDeclaration): string {
    let output = `type ${node.name}* = ref object\n`;
    
    if (node.constructor) {
      this.indent++;
      for (const param of node.constructor.parameters) {
        output += this.getIndent() + `${param.name}*: auto\n`;
      }
      this.indent--;
    }
    
    output += '\n';
    
    if (node.constructor) {
      output += this.generateConstructor(node.name, node.constructor) + '\n';
    } else {
      output += this.generateDefaultConstructor(node.name) + '\n';
    }
    
    for (const method of node.methods) {
      output += this.generateMethod(node.name, method) + '\n';
    }
    
    return output;
  }

  private generateConstructor(className: string, constructor: ConstructorDeclaration): string {
    const params = constructor.parameters.map(p => `${p.name}: auto`).join(', ');
    let output = `proc new${className}*(${params}): ${className} =\n`;
    
    this.indent++;
    this.inConstructor = true;
    output += this.getIndent() + `result = ${className}()\n`;
    
    for (const stmt of constructor.body) {
      output += this.generateStatement(stmt);
    }
    
    this.inConstructor = false;
    this.indent--;
    return output;
  }

  private generateDefaultConstructor(className: string): string {
    let output = `proc new${className}*(): ${className} =\n`;
    
    this.indent++;
    output += this.getIndent() + `result = ${className}()\n`;
    this.indent--;
    
    return output;
  }

  private generateMethod(className: string, method: MethodDeclaration): string {
    const params = ['self: ' + className].concat(
      method.parameters.map(p => `${p.name}: auto`)
    ).join(', ');
    
    let output = `proc ${method.name}*(${params})`;
    
    const hasReturn = method.body.some(stmt => stmt.type === 'ReturnStatement');
    if (hasReturn) {
      output += ': auto';
    }
    
    output += ' =\n';
    
    this.indent++;
    for (const stmt of method.body) {
      output += this.generateStatement(stmt);
    }
    this.indent--;
    
    return output;
  }

  private generateStatement(stmt: Statement): string {
    switch (stmt.type) {
      case 'AssignmentStatement':
        return this.generateAssignmentStatement(stmt as AssignmentStatement);
      case 'ReturnStatement':
        return this.generateReturnStatement(stmt as ReturnStatement);
      case 'VariableDeclaration':
        return this.generateVariableDeclaration(stmt as VariableDeclaration);
      case 'ExpressionStatement':
        return this.generateExpressionStatement(stmt as ExpressionStatement);
      case 'ForStatement':
        return this.generateForStatement(stmt as ForStatement);
      case 'WhileStatement':
        return this.generateWhileStatement(stmt as WhileStatement);
      case 'IfStatement':
        return this.generateIfStatement(stmt as IfStatement);
      default:
        throw new Error(`Unknown statement type: ${stmt.type}`);
    }
  }

  private generateAssignmentStatement(stmt: AssignmentStatement): string {
    const left = this.generateExpression(stmt.left);
    const right = this.generateExpression(stmt.right);
    return this.getIndent() + `${left} = ${right}\n`;
  }

  private generateReturnStatement(stmt: ReturnStatement): string {
    const expr = this.generateExpression(stmt.expression);
    return this.getIndent() + `return ${expr}\n`;
  }

  private generateVariableDeclaration(stmt: VariableDeclaration): string {
    const initializer = this.generateExpression(stmt.initializer);
    const exportMark = this.indent === 0 ? '*' : '';
    return this.getIndent() + `var ${stmt.name}${exportMark} = ${initializer}\n`;
  }

  private generateExpressionStatement(stmt: ExpressionStatement): string {
    const expr = this.generateExpression(stmt.expression);
    return this.getIndent() + expr + '\n';
  }

  private generateExpression(expr: Expression): string {
    switch (expr.type) {
      case 'CallExpression':
        return this.generateCallExpression(expr as CallExpression);
      case 'MemberExpression':
        return this.generateMemberExpression(expr as MemberExpression);
      case 'Identifier':
        return this.generateIdentifier(expr as Identifier);
      case 'StringLiteral':
        return this.generateStringLiteral(expr as StringLiteral);
      case 'NumberLiteral':
        return this.generateNumberLiteral(expr as NumberLiteral);
      case 'BooleanLiteral':
        return this.generateBooleanLiteral(expr as BooleanLiteral);
      case 'FunctionExpression':
        return this.generateFunctionExpression(expr as FunctionExpression);
      case 'BinaryExpression':
        return this.generateBinaryExpression(expr as BinaryExpression);
      case 'NewExpression':
        return this.generateNewExpression(expr as NewExpression);
      case 'ArrayLiteral':
        return this.generateArrayLiteral(expr as ArrayLiteral);
      case 'ArrayAccess':
        return this.generateArrayAccess(expr as ArrayAccess);
      case 'NimCallExpression':
        return this.generateNimCallExpression(expr as NimCallExpression);
      default:
        throw new Error(`Unknown expression type: ${expr.type}`);
    }
  }

  private generateCallExpression(expr: CallExpression): string {
    const callee = this.generateExpression(expr.callee);
    const args = expr.arguments.map(arg => this.generateExpression(arg)).join(', ');
    
    if (expr.callee.type === 'MemberExpression') {
      const memberExpr = expr.callee as MemberExpression;
      const obj = this.generateExpression(memberExpr.object);
      
      if (memberExpr.property === 'parler') {
        return `${obj}.parler(${args})`;
      } else if (memberExpr.property === 'recupererNom') {
        return `${obj}.recupererNom()`;
      }
      
      return `${obj}.${memberExpr.property}(${args})`;
    }
    
    return `${callee}(${args})`;
  }

  private generateMemberExpression(expr: MemberExpression): string {
    const obj = this.generateExpression(expr.object);
    return `${obj}.${expr.property}`;
  }

  private generateIdentifier(expr: Identifier): string {
    if (expr.name === 'self') {
      return this.inConstructor ? 'result' : 'self';
    }
    return expr.name;
  }

  private generateStringLiteral(expr: StringLiteral): string {
    const escapedValue = expr.value.replace(/"/g, '\\"').replace(/'/g, "\\'");
    return `"${escapedValue}"`;
  }

  private generateNumberLiteral(expr: NumberLiteral): string {
    return expr.value.toString();
  }

  private generateBooleanLiteral(expr: BooleanLiteral): string {
    return expr.value ? 'true' : 'false';
  }

  private generateFunctionExpression(expr: FunctionExpression): string {
    const params = expr.parameters.map(p => `${p.name}: auto`).join(', ');
    let output = `proc(${params}): auto {.closure, gcsafe.} =\n`;
    
    this.indent++;
    for (const stmt of expr.body) {
      output += this.generateStatement(stmt);
    }
    this.indent--;
    
    return output;
  }

  private generateBinaryExpression(expr: BinaryExpression): string {
    const left = this.generateExpression(expr.left);
    const right = this.generateExpression(expr.right);

    let op = expr.operator;
    
    return `(${left}${op}${right})`;
  }

  private generateNewExpression(expr: NewExpression): string {
    const callee = this.generateExpression(expr.callee);
    const args = expr.arguments.map(arg => this.generateExpression(arg)).join(', ');
    return `${callee}(${args})`;
  }

  private generateForStatement(stmt: ForStatement): string {
    let output = '';
    
    if (!stmt.init && !stmt.condition && !stmt.increment) {
      output += this.getIndent() + 'while true:\n';
    } else {
      if (stmt.init) {
        output += this.getIndent() + this.generateExpression(stmt.init) + '\n';
      }
      
      if (stmt.condition) {
        output += this.getIndent() + 'while ' + this.generateExpression(stmt.condition) + ':\n';
      } else {
        output += this.getIndent() + 'while true:\n';
      }
    }
    
    this.indent++;
    for (const bodyStmt of stmt.body) {
      output += this.generateStatement(bodyStmt);
    }
    
    if (stmt.increment) {
      output += this.getIndent() + this.generateExpression(stmt.increment) + '\n';
    }
    
    this.indent--;
    
    return output;
  }

  private generateWhileStatement(stmt: WhileStatement): string {
    let output = this.getIndent() + 'while ' + this.generateExpression(stmt.condition) + ':\n';
    
    this.indent++;
    for (const bodyStmt of stmt.body) {
      output += this.generateStatement(bodyStmt);
    }
    this.indent--;
    
    return output;
  }

  private generateArrayLiteral(expr: ArrayLiteral): string {
    const elements = expr.elements.map(element => this.generateExpression(element));
    
    if (elements.length === 0) {
      return `newSeq[string]()`;
    }
    
    return `@[${elements.join(', ')}]`;
  }

  private generateArrayAccess(expr: ArrayAccess): string {
    const array = this.generateExpression(expr.array);
    const index = this.generateExpression(expr.index);
    return `${array}[${index}]`;
  }

  private generateNimCallExpression(expr: NimCallExpression): string {
    let nimCode = expr.code;

    nimCode = nimCode.replace(/"/g, '"');
    
    return nimCode;
  }

  private generateTypeDeclaration(node: TypeDeclaration): string {
    if (node.typeKind === 'external') {
      return `# External type: ${node.name}`;
    } else {
      return `type ${node.name}* = object`;
    }
  }

  private generateConstantDeclaration(node: ConstantDeclaration): string {
    const value = this.generateExpression(node.value);
    return `const ${node.name}* = ${value}`;
  }

  private generateFunctionDeclaration(node: FunctionDeclaration): string {
    const params = node.parameters.map(p => `${p.name}: auto`).join(', ');
    let output = `proc ${node.name}*(${params})`;
    

    const hasReturn = node.body.some(stmt => stmt.type === 'ReturnStatement');
    if (hasReturn) {
      output += ': auto';
    }
    
    output += ' =\n';
    
    this.indent++;
    for (const stmt of node.body) {
      output += this.generateStatement(stmt);
    }
    this.indent--;
    
    return output;
  }

  private generateIfStatement(stmt: IfStatement): string {
    let output = this.getIndent() + 'if ' + this.generateExpression(stmt.condition) + ':\n';
    
    this.indent++;
    for (const thenStmt of stmt.thenBranch) {
      output += this.generateStatement(thenStmt);
    }
    this.indent--;
    
    if (stmt.elseBranch && stmt.elseBranch.length > 0) {
      output += this.getIndent() + 'else:\n';
      this.indent++;
      for (const elseStmt of stmt.elseBranch) {
        output += this.generateStatement(elseStmt);
      }
      this.indent--;
    }
    
    return output;
  }

  private getIndent(): string {
    return '  '.repeat(this.indent);
  }
}