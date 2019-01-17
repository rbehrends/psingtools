// vim:ft=d:

import std.algorithm;
import file = std.file;
import std.ascii;
import enumset;

@safe:

private string[] words(string text) {
  string[] result = [];
  string word = "";
  foreach(ch; text) {
    switch (ch) {
      case ' ':
      case '\n':
      case '\r':
        if (word.length != 0) {
          result ~= word;
          word = "";
        }
        break;
      default:
        word ~= ch;
    }
  }
  if (word.length != 0)
    result ~= word;
  return result;
}

private string capitalize(string str) {
  return "" ~ toUpper(str[0]) ~ str[1..$];
}

enum keywords = `
  class struct union
  extern static volatile const
  typedef using namespace
  VAR EXTERN_VAR STATIC_VAR INST_VAR EXTERN_INST_VAR STATIC_INST_VAR
  GLOBAL_VAR
  `;

enum keywordList = keywords.words;

enum symbols = (`
  None` ~ keywords ~ `
  Ident
  BAD EOL EOF WS Comment
  Op Comma Semicolon ColonColon Ast And AndAnd Equal
  LPar RPar LBrkt RBrkt LBrace RBrace
  Literal
  OpPP
  PPIf PPElif PPElse PPEndif PPDef PPInclude PPOther
  `).words;

private string genEnum(string typename, string prefix, string[] symbols) {
  string result = "enum " ~ typename ~ " {\n";
  foreach (sym; symbols) {
    result ~= "  " ~ sym.capitalize ~ ",\n";
  }
  result ~= "};\n";
  foreach (sym; symbols) {
    result ~= "enum " ~ prefix ~ sym.capitalize ~
      " = " ~ typename ~ "." ~ sym.capitalize ~ ";\n";
  }
  return result;
}

private string genKeywordInit(string[] keywords) {
  string result = "static this() {\n";
  foreach(keyword; keywords) {
    result ~= `keywordToSym["` ~ keyword ~ `"] = Sym` ~
      keyword.capitalize ~";\n";
  }
  result ~= "}\n";
  return result;
}

mixin(genEnum("Symbol", "Sym", symbols));

alias Sym = Symbol;

Symbol[string] keywordToSym;

mixin(genKeywordInit(keywordList));

alias SymbolSet = EnumSet!(Symbol);

const skip = SymbolSet(SymNone, SymBAD, SymEOL, SymWS, SymComment,
  SymPPIf, SymPPElif, SymPPElse, SymPPEndif, SymPPDef, SymPPInclude,
  SymPPOther);

const special = SymbolSet(SymVAR, SymSTATIC_VAR, SymEXTERN_VAR,
  SymINST_VAR, SymEXTERN_INST_VAR, SymSTATIC_INST_VAR);

class Token {
  Symbol sym;
  string text;
  this(Symbol sym, string text) {
    this.sym = sym;
    this.text = text;
  }
  @property
  Symbol symbol() {
    return sym;
  }
}

class SourceFile {
  Token[] tokens;
  const string input;
  const string filename;
  this(string filename, string input, Token[] tokens) {
    this.filename = filename;
    this.input = input;
    this.tokens = tokens;
  }
}

struct ScannerSpec {
  alias Token = .Token;
  alias Symbol = .Symbol;
  alias SymbolSet = .SymbolSet;
  enum eof = SymEOF;
  enum skip = .skip;
}

@trusted // We're working with pointer arithmetic here
Token[] lexer(string input) {
  if (!input.endsWith('\0'))
    input ~= '\0';
  Token[] result = [];
  char *start = cast(char*)input.ptr;
  char *cursor = start;
  char *marker = start;
  char *ctxmarker = start;
  char *last = cursor;
  char *preproc = null;
  bool done = false;
  bool error = false;
  void beginPP() {
    preproc = last;
  }
  void endPP() {
    if (preproc !is null)
      result[$-1].text = input[preproc-start..last-start];
    preproc = null;
  }
  void emit(Symbol sym) {
    // Note: this does not actually copy text, but simply creates
    // a reference to the underlying string.
    import std.stdio;
    if (preproc is null) {
      // Do not create tokens while scanning a preprocessor directive
      string text = input[last-start..cursor-start];
      result ~= new Token(sym, text);
    }
  }
  while (!done) {
    last = cursor;
    /*!re2c
      re2c:define:YYCTYPE = char;
      re2c:define:YYCURSOR = cursor;
      re2c:define:YYMARKER = marker;
      re2c:define:YYCTXMARKER = ctxmarker;
      re2c:yyfill:enable = 0;

      alpha = [a-zA-Z_];
      digit = [0-9];
      oct = [0-7];
      hex = [0-9a-fA-F];
      floatsuffix = [fFlL]?;
      intsuffix = [uUlL]*;
      exp = 'e' [-+]? digit+;
      squote = ['];
      quote = ["];
      any = [^\000\r\n];
      sp = [ \t\f];
      eol = [\000\r\n];
      nl = "\r" | "\n" | "\r\n";
      postpparg = [^a-zA-Z0-9_\r\n\000];
      pparg = (postpparg any *)?;
      anystr = (any \ ["\\] | "\\" sp* nl | nl);
      anych = any \ ['\\];
      longops = "..." | ">>=" | "<<=" | "+=" | "-=" | "*=" | "/=" | "%="
	      | "&=" | "^=" | "|=" | ">>" | "<<" | "++" | "--" | "->"
	      | "&&" | "||" | "<=" | ">=" | "==" | "!=";
      esc = "\\";

      alpha (alpha | digit) * {
        string text = cast(string)(last[0..cursor-last]);
        Symbol *symp = text in keywordToSym;
        if (symp is null) {
          if (preproc is null) result ~= new Token(SymIdent, text);
        } else {
          if (preproc is null) result ~= new Token(*symp, text);
        }
        continue;
      }
      '0x' hex+ intsuffix { emit(SymLiteral); continue; }
      '0' oct+ intsuffix { emit(SymLiteral); continue; }
      digit+ intsuffix { emit(SymLiteral); continue; }
      "L"? squote (esc any anych* | anych) squote { emit(SymLiteral); continue; }
      "L"? quote (esc any | anystr)* quote { emit(SymLiteral); continue; }
      digit+ exp floatsuffix { emit(SymLiteral); continue; }
      digit* "." digit+ exp? floatsuffix { emit(SymLiteral); continue; }
      digit+ "." digit* exp? floatsuffix { emit(SymLiteral); continue; }
      "(" { emit(SymLPar); continue; }
      ")" { emit(SymRPar); continue; }
      "[" { emit(SymLBrkt); continue; }
      "]" { emit(SymRBrkt); continue; }
      "{" { emit(SymLBrace); continue; }
      "}" { emit(SymRBrace); continue; }
      "*" { emit(SymAst); continue; }
      "&" { emit(SymAnd); continue; }
      "=" { emit(SymEqual); continue; }
      "&&" { emit(SymAndAnd); continue; }
      "," { emit(SymComma); continue; }
      ";" { emit(SymSemicolon); continue; }
      "::" { emit(SymColonColon); continue; }
      // The generic SymOp rules may contain duplicates for
      // the more specific cases. This is intentional so that
      // we can add/remove specific cases without breaking
      // the scanner.
      [-.&!~+*%/<>^|?:=,] { emit(SymOp); continue; }
      longops { emit(SymOp); continue; }
      "//" any+ { emit(SymComment); continue; }
      "/" "*" { goto comment; }
      nl { endPP(); emit(SymEOL); continue; }
      "\\" sp* / nl { emit(SymWS); continue; }
      sp+ { emit(SymWS); continue; }
      "#" | "##" { if (preproc !is null) { emit(SymOpPP); continue; } }
      "#" sp* "if" sp+ "0" sp* nl { goto if0; }
      "#" sp* "if" { emit(SymPPIf); beginPP(); continue; }
      "#" sp* "ifdef" { emit(SymPPIf); beginPP(); continue; }
      "#" sp* "ifndef" { emit(SymPPIf); beginPP(); continue; }
      "#" sp* "else" { emit(SymPPElse); beginPP(); continue; }
      "#" sp* "elif" { emit(SymPPElif); beginPP(); continue; }
      "#" sp* "endif" { emit(SymPPEndif); beginPP(); continue; }
      "#" sp* "define" { emit(SymPPDef); beginPP(); continue; }
      "#" sp* "undefine" { emit(SymPPDef); beginPP(); continue; }
      "#" sp* alpha+ {
        emit(SymPPOther);
        if (preproc is null)
          beginPP();
        continue;
      }
      "\000" { done = true; continue; }
      any { error = true; emit(SymBAD); continue; }
      * { endPP(); done = true; continue; }
    */
    comment:
    /*!re2c
      "*" "/" { emit(SymComment); continue; }
      [^\000] { goto comment; }
      "\000" { done = true; emit(SymComment); continue; }
    */
    if0:
    /*!re2c
      "#" sp* "endif" nl { emit(SymComment); continue; }
      [^\000] { goto if0; }
      "\000" { done = true; emit(SymComment); continue; }
    */
  }
  result ~= new Token(SymEOF, "");
  return result;
}

@trusted
SourceFile scanFile(string filename) {
  string contents = cast(string)(file.read(filename));
  return new SourceFile(filename, contents, lexer(contents));
}
