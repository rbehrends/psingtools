import std.stdio;

import parser, scanner;

@safe:

class Declaration {
  size_t start;
  size_t extern_pos;
  size_t static_pos;
  bool is_extern;
  bool is_static;
  bool is_const;
  bool is_volatile;
  bool is_class;
}


class CppParser : parser.Parser!(scanner.ScannerSpec) {
  Declaration declaration;
  this(Token[] tokens) {
    super(tokens);
  }
  string[] classNames() {
    string[] result;
    const marker = SymbolSet(SymEOF, SymClass);
    parse(() {
      while (true) {
        skipUntil(marker);
        switch (current.symbol) {
          case SymEOF:
            return;
          case SymClass:
            advance();
            if (current.symbol == SymIdent) {
              if (next.text == "::") break;
              if (next.text == ">") break;
              if (next.text == "<") break;
              if (next.text == ",") break;
              result ~= current.text;
            }
            break;
          default:
            assert(false);
        }
      }
    });
    return result;
  }
  struct Segment {
    size_t start, end, depth;
  }
  Segment[] segments() {
    size_t depth = 0;
    Segment[] result;
    size_t last = 0;
    const marker = SymbolSet(SymEOF, SymLBrace, SymRBrace, SymSemicolon);
    parse(() {
      while (true) {
        skipUntil(marker);
        switch (current.symbol) {
          case SymEOF:
            return;
          case SymSemicolon:
            result ~= Segment(last, currentPos, depth);
            advance();
            last = currentPos;
            break;
          case SymLBrace:
            result ~= Segment(last, currentPos, depth);
            depth++;
            advance();
            last = currentPos;
            break;
          case SymRBrace:
            result ~= Segment(last, currentPos, depth);
            if (depth > 0)
              depth--;
            advance();
            last = currentPos;
            break;
          default:
            assert(false);
        }
      }
    });
    return result;
  }
  void parseTypeQualifiers() {
    for (;;) {
      switch (current.symbol) {
        case SymExtern:
          declaration.is_extern = true;
          declaration.extern_pos = currentPos;
          break;
        case SymStatic:
          declaration.is_static = true;
          declaration.static_pos = currentPos;
          break;
        case SymConst:
          declaration.is_const = true;
          break;
        case SymVolatile:
          declaration.is_volatile = true;
          break;
        default:
          return;
      }
      advance();
    }
  }
  void skipPar(Symbol left, Symbol right) {
    if (current.symbol != left) {
      fail();
      return;
    }
    advance();
    int depth = 1;
    for (;;) {
      if (current.symbol == SymEOF) {
        fail();
        return;
      } else if (current.symbol == left) {
        advance();
        depth ++;
      } else if (current.symbol == right) {
        advance();
        depth--;
        if (depth == 0) {
          return;
        }
      }
    }
  }
  Declaration parseDeclaration(Segment seg, bool[string] isClass) {
    declaration = new Declaration();
    parseTypeQualifiers(); // always succeeds
    int nsyms = 0;
    if (current.symbol != SymIdent) {
      fail();
      return null;      
    }
    nsyms++;
    auto marker = mark();
    while (next.symbol == SymIdent) { // includes char, int, etc.
      nsyms++;
      advance();
    }
    switch (next.symbol) {
      case SymComma:
      case SymSemicolon:
      case SymEqual:
      case SymLBrkt:
        if (nsyms < 2)
          return null;
        if (current.text in isClass) {
          declaration.is_class = true;
        }
        return declaration;
      case SymAst:
      case SymAnd:
        advance();
        while (current.symbol == SymAnd || current.symbol == SymAst)
          advance();
        if (current.symbol == SymIdent) {
          switch (next.symbol) {
            case SymComma:
            case SymSemicolon:
            case SymEqual:
            case SymLBrkt:
              return declaration;
            default:
              return null;
          }
        }
        else
          return null;
      case SymLPar:
        advance();
        if (next.symbol == SymAst && peek(2).symbol == SymIdent) {
          skipPar(SymLPar, SymRPar);
          if (ok && current.symbol == SymLPar) {
            skipPar(SymLPar, SymRPar);
            return declaration;
          }
        }
        return null;
      default:
        fail();
        return null;
    }
  }
  Declaration parseSegment(Segment segment, bool[string] isClass) {
    Declaration parseIt() {
      return parseDeclaration(segment, isClass);
    }
    return parse!Declaration(&parseIt, segment.start, segment.end);
  }
}
