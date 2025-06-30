import types, tables, strutils

type
  Lexer* = object
    source: string
    position: int
    line: int
    column: int
    keywords: Table[string, TokenType]

proc newLexer*(source: string): Lexer =
  var keywords = initTable[string, TokenType]()
  keywords["classe"] = CLASSE
  keywords["constructeur"] = CONSTRUCTEUR
  keywords["variable"] = VARIABLE
  keywords["nouveau"] = NOUVEAU
  keywords["retourne"] = RETOURNE
  keywords["retourner"] = RETOURNE
  keywords["ceci"] = CECI
  keywords["cette"] = CECI
  keywords["ouvrir"] = OUVRIR
  keywords["refermer"] = REFERMER
  keywords["egal"] = EGAL
  keywords["importer"] = IMPORT
  keywords["de"] = FROM
  keywords["comme"] = AS
  keywords["pour"] = POUR
  keywords["tantque"] = TANTQUE
  keywords["fonction"] = FONCTION
  keywords["type"] = TYPE
  keywords["external"] = EXTERNAL
  keywords["constant"] = CONSTANT
  keywords["nim"] = NIM
  keywords["si"] = SI
  keywords["sinon"] = SINON
  keywords["vrai"] = BOOLEAN
  keywords["faux"] = BOOLEAN
  
  result = Lexer(
    source: source,
    position: 0,
    line: 1,
    column: 1,
    keywords: keywords
  )

proc isAtEnd(lexer: Lexer): bool =
  lexer.position >= lexer.source.len

proc advance(lexer: var Lexer): char =
  if not lexer.isAtEnd():
    result = lexer.source[lexer.position]
    lexer.position += 1
    lexer.column += 1
  else:
    result = '\0'

proc peek(lexer: Lexer): char =
  if lexer.isAtEnd():
    return '\0'
  return lexer.source[lexer.position]

proc peekNext(lexer: Lexer): char =
  if lexer.position + 1 >= lexer.source.len:
    return '\0'
  return lexer.source[lexer.position + 1]

proc skipWhitespace(lexer: var Lexer) =
  while not lexer.isAtEnd():
    let ch = lexer.peek()
    if ch in [' ', '\r', '\t']:
      discard lexer.advance()
    else:
      break

proc isAlpha(ch: char): bool =
  ch.isAlphaAscii or ch in "àâäéèêëïîôöùûüÿçñÀÂÄÉÈÊËÏÎÔÖÙÛÜŸÇÑ_"

proc isDigit(ch: char): bool =
  ch >= '0' and ch <= '9'

proc makeToken(lexer: Lexer, tokenType: TokenType, value: string): Token =
  newToken(tokenType, value, lexer.line, lexer.column - value.len)

proc scanString(lexer: var Lexer, quote: char): Token =
  var value = ""
  
  while not lexer.isAtEnd() and lexer.peek() != quote:
    if lexer.peek() == '\\':
      discard lexer.advance()
      if not lexer.isAtEnd():
        let escaped = lexer.advance()
        case escaped:
        of 'n': value.add('\n')
        of 't': value.add('\t')
        of 'r': value.add('\r')
        of '\\': value.add('\\')
        of '"': value.add('"')
        of '\'': value.add('\'')
        else: value.add(escaped)
    else:
      if lexer.peek() == '\n':
        lexer.line += 1
        lexer.column = 1
      value.add(lexer.advance())
  
  if lexer.isAtEnd():
    raise newException(ValueError, "Unterminated string at line " & $lexer.line)
  
  discard lexer.advance()  # closing quote
  return lexer.makeToken(STRING, value)

proc scanIdentifier(lexer: var Lexer): Token =
  var value = $lexer.source[lexer.position - 1]
  
  while not lexer.isAtEnd() and (lexer.peek().isAlpha or lexer.peek().isDigit):
    value.add(lexer.advance())
  
  let tokenType = lexer.keywords.getOrDefault(value, IDENTIFIER_TOKEN)
  return lexer.makeToken(tokenType, value)

proc scanNumber(lexer: var Lexer): Token =
  var value = $lexer.source[lexer.position - 1]
  
  while not lexer.isAtEnd() and lexer.peek().isDigit:
    value.add(lexer.advance())
  
  if not lexer.isAtEnd() and lexer.peek() == '.' and lexer.peekNext().isDigit:
    value.add(lexer.advance())
    
    while not lexer.isAtEnd() and lexer.peek().isDigit:
      value.add(lexer.advance())
  
  return lexer.makeToken(NUMBER, value)

proc skipLineComment(lexer: var Lexer) =
  discard lexer.advance()  # second '/'
  
  while not lexer.isAtEnd() and lexer.peek() != '\n':
    discard lexer.advance()

proc skipBlockComment(lexer: var Lexer) =
  discard lexer.advance()  # '*'
  
  while not lexer.isAtEnd():
    if lexer.peek() == '*' and lexer.peekNext() == '/':
      discard lexer.advance()
      discard lexer.advance()
      break
    
    if lexer.peek() == '\n':
      lexer.line += 1
      lexer.column = 1
    
    discard lexer.advance()

proc scanToken(lexer: var Lexer): Token =
  let ch = lexer.advance()
  
  case ch:
  of '(':
    return lexer.makeToken(PAREN_OPEN, "(")
  of ')':
    return lexer.makeToken(PAREN_CLOSE, ")")
  of '+':
    return lexer.makeToken(PLUS, "+")
  of '-':
    if lexer.peek() == '>':
      discard lexer.advance()
      return lexer.makeToken(FLECHE, "->")
    return lexer.makeToken(MINUS, "-")
  of ',':
    return lexer.makeToken(COMMA, ",")
  of '.':
    return lexer.makeToken(DOT, ".")
  of '{':
    return lexer.makeToken(BRACE_OPEN, "{")
  of '}':
    return lexer.makeToken(BRACE_CLOSE, "}")
  of '[':
    return lexer.makeToken(BRACKET_OPEN, "[")
  of ']':
    return lexer.makeToken(BRACKET_CLOSE, "]")
  of ';':
    return lexer.makeToken(SEMICOLON, ";")
  of ':':
    return lexer.makeToken(COLON, ":")
  of '@':
    return lexer.makeToken(AT, "@")
  of '=':
    if lexer.peek() == '=':
      discard lexer.advance()
      return lexer.makeToken(EGALE, "==")
    # No direct EGAL token, handled by keyword
    raise newException(ValueError, "Unexpected character '=' at line " & $lexer.line)
  of '!':
    if lexer.peek() == '=':
      discard lexer.advance()
      return lexer.makeToken(DIFFERENT, "!=")
    raise newException(ValueError, "Unexpected character '!' at line " & $lexer.line)
  of '<':
    if lexer.peek() == '=':
      discard lexer.advance()
      return lexer.makeToken(INFERIEUR_EGAL, "<=")
    return lexer.makeToken(INFERIEUR, "<")
  of '>':
    if lexer.peek() == '=':
      discard lexer.advance()
      return lexer.makeToken(SUPERIEUR_EGAL, ">=")
    return lexer.makeToken(SUPERIEUR, ">")
  of '"':
    return lexer.scanString('"')
  of '\'':
    return lexer.scanString('\'')
  of '/':
    if lexer.peek() == '/':
      lexer.skipLineComment()
      # Return a special token to indicate comment was skipped
      return newToken(NEWLINE, "", lexer.line, lexer.column)
    elif lexer.peek() == '*':
      lexer.skipBlockComment()
      # Return a special token to indicate comment was skipped
      return newToken(NEWLINE, "", lexer.line, lexer.column)
    else:
      raise newException(ValueError, "Unexpected character '/' at line " & $lexer.line)
  of '\n':
    lexer.line += 1
    lexer.column = 1
    return lexer.makeToken(NEWLINE, "\n")
  else:
    if ch.isAlpha:
      return lexer.scanIdentifier()
    elif ch.isDigit:
      return lexer.scanNumber()
    else:
      raise newException(ValueError, "Unexpected character '" & $ch & "' at line " & $lexer.line)

proc tokenize*(lexer: var Lexer): seq[Token] =
  var tokens: seq[Token] = @[]
  
  while not lexer.isAtEnd():
    lexer.skipWhitespace()
    if lexer.isAtEnd():
      break
    
    let token = lexer.scanToken()
    # Skip comment placeholders (empty NEWLINE tokens)
    if token.tokenType != NEWLINE or token.value != "":
      tokens.add(token)
  
  tokens.add(newToken(EOF, "", lexer.line, lexer.column))
  return tokens