import { Token, TokenType } from './types';

export class Lexer {
  private source: string;
  private position: number = 0;
  private line: number = 1;
  private column: number = 1;

  private keywords: Record<string, TokenType> = {
    'classe': TokenType.CLASSE,
    'constructeur': TokenType.CONSTRUCTEUR,
    'variable': TokenType.VARIABLE,
    'nouveau': TokenType.NOUVEAU,
    'retourne': TokenType.RETOURNE,
    'retourner': TokenType.RETOURNE,
    'ceci': TokenType.CECI,
    'cette': TokenType.CECI,
    'ouvrir': TokenType.OUVRIR,
    'refermer': TokenType.REFERMER,
    'egal': TokenType.EGAL,
    'importer': TokenType.IMPORT,
    'de': TokenType.FROM,
    'comme': TokenType.AS,
    'pour': TokenType.POUR,
    'tantque': TokenType.TANTQUE,
    'fonction': TokenType.FONCTION,
    'type': TokenType.TYPE,
    'external': TokenType.EXTERNAL,
    'constant': TokenType.CONSTANT,
    'nim': TokenType.NIM,
    'si': TokenType.SI,
    'sinon': TokenType.SINON,
    'vrai': TokenType.BOOLEAN,
    'faux': TokenType.BOOLEAN,
  };

  constructor(source: string) {
    this.source = source;
  }

  tokenize(): Token[] {
    const tokens: Token[] = [];
    
    while (!this.isAtEnd()) {
      this.skipWhitespace();
      if (this.isAtEnd()) break;

      const start = this.position;
      const token = this.scanToken();
      if (token) {
        tokens.push(token);
      }
    }

    tokens.push({
      type: TokenType.EOF,
      value: '',
      line: this.line,
      column: this.column
    });

    return tokens;
  }

  private scanToken(): Token | null {
    const char = this.advance();

    switch (char) {
      case '(':
        return this.makeToken(TokenType.PAREN_OPEN, '(');
      case ')':
        return this.makeToken(TokenType.PAREN_CLOSE, ')');
      case '+':
        return this.makeToken(TokenType.PLUS, '+');
      case '-':
        if (this.peek() === '>') {
          this.advance();
          return this.makeToken(TokenType.FLECHE, '->');
        }
        return this.makeToken(TokenType.MINUS, '-');
      case ',':
        return this.makeToken(TokenType.COMMA, ',');
      case '.':
        return this.makeToken(TokenType.DOT, '.');
      case '{':
        return this.makeToken(TokenType.BRACE_OPEN, '{');
      case '}':
        return this.makeToken(TokenType.BRACE_CLOSE, '}');
      case '[':
        return this.makeToken(TokenType.BRACKET_OPEN, '[');
      case ']':
        return this.makeToken(TokenType.BRACKET_CLOSE, ']');
      case ';':
        return this.makeToken(TokenType.SEMICOLON, ';');
      case ':':
        return this.makeToken(TokenType.COLON, ':');
      case '@':
        return this.makeToken(TokenType.AT, '@');
      case '=':
        if (this.peek() === '=') {
          this.advance();
          return this.makeToken(TokenType.EGALE, '==');
        }
        break;
      case '!':
        if (this.peek() === '=') {
          this.advance();
          return this.makeToken(TokenType.DIFFERENT, '!=');
        }
        break;
      case '<':
        if (this.peek() === '=') {
          this.advance();
          return this.makeToken(TokenType.INFERIEUR_EGAL, '<=');
        }
        return this.makeToken(TokenType.INFERIEUR, '<');
      case '>':
        if (this.peek() === '=') {
          this.advance();
          return this.makeToken(TokenType.SUPERIEUR_EGAL, '>=');
        }
        return this.makeToken(TokenType.SUPERIEUR, '>');
      case '"':
        return this.scanString('"');
      case "'":
        return this.scanString("'");
      case '/':
        if (this.peek() === '/') {
          this.skipLineComment();
          return null;
        } else if (this.peek() === '*') {
          this.skipBlockComment();
          return null;
        }
        break;
      case '\n':
        this.line++;
        this.column = 1;
        return this.makeToken(TokenType.NEWLINE, '\n');
      default:
        if (this.isAlpha(char)) {
          return this.scanIdentifier();
        }
        if (this.isDigit(char)) {
          return this.scanNumber();
        }
        break;
    }

    return null;
  }

  private scanString(quote: string = '"'): Token {
    let value = '';
    
    while (!this.isAtEnd() && this.peek() !== quote) {
      if (this.peek() === '\\') {
        this.advance();
        if (!this.isAtEnd()) {
          const escaped = this.advance();
          switch (escaped) {
            case 'n': value += '\n'; break;
            case 't': value += '\t'; break;
            case 'r': value += '\r'; break;
            case '\\': value += '\\'; break;
            case '"': value += '"'; break;
          case "'": value += "'"; break;
            default: value += escaped; break;
          }
        }
      } else {
        if (this.peek() === '\n') {
          this.line++;
          this.column = 1;
        }
        value += this.advance();
      }
    }

    if (this.isAtEnd()) {
      throw new Error(`Unterminated string at line ${this.line}`);
    }

    this.advance(); // closing quote
    return this.makeToken(TokenType.STRING, value);
  }

  private scanIdentifier(): Token {
    let value = this.source[this.position - 1];
    
    while (!this.isAtEnd() && (this.isAlpha(this.peek()) || this.isDigit(this.peek()))) {
      value += this.advance();
    }

    const tokenType = this.keywords[value] || TokenType.IDENTIFIER;
    return this.makeToken(tokenType, value);
  }

  private scanNumber(): Token {
    let value = this.source[this.position - 1];
    
    while (!this.isAtEnd() && this.isDigit(this.peek())) {
      value += this.advance();
    }

    if (!this.isAtEnd() && this.peek() === '.' && this.isDigit(this.peekNext())) {
      value += this.advance();
      
      while (!this.isAtEnd() && this.isDigit(this.peek())) {
        value += this.advance();
      }
    }

    return this.makeToken(TokenType.NUMBER, value);
  }

  private makeToken(type: TokenType, value: string): Token {
    return {
      type,
      value,
      line: this.line,
      column: this.column - value.length
    };
  }

  private advance(): string {
    const char = this.source[this.position];
    this.position++;
    this.column++;
    return char;
  }

  private peek(): string {
    if (this.isAtEnd()) return '\0';
    return this.source[this.position];
  }

  private peekNext(): string {
    if (this.position + 1 >= this.source.length) return '\0';
    return this.source[this.position + 1];
  }

  private skipWhitespace(): void {
    while (!this.isAtEnd()) {
      const char = this.peek();
      if (char === ' ' || char === '\r' || char === '\t') {
        this.advance();
      } else {
        break;
      }
    }
  }

  private isAtEnd(): boolean {
    return this.position >= this.source.length;
  }

  private isAlpha(char: string): boolean {
    return /[a-zA-ZàâäéèêëïîôöùûüÿçñÀÂÄÉÈÊËÏÎÔÖÙÛÜŸÇÑ_]/.test(char);
  }

  private isDigit(char: string): boolean {
    return /[0-9]/.test(char);
  }

  private skipLineComment(): void {
    this.advance();
    
    while (!this.isAtEnd() && this.peek() !== '\n') {
      this.advance();
    }
  }

  private skipBlockComment(): void {
    this.advance();
    
    while (!this.isAtEnd()) {
      if (this.peek() === '*' && this.peekNext() === '/') {
        this.advance();
        this.advance();
        break;
      }
      
      if (this.peek() === '\n') {
        this.line++;
        this.column = 1;
      }
      
      this.advance();
    }
  }
}