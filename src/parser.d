import std.algorithm.comparison;

@safe:

struct Mark {
  bool err;
  size_t pos;
}

class Parser(Spec)
    if (__traits(compiles, () {
        Spec.Token token;
        Spec.Symbol symbol;
        Spec.SymbolSet set = Spec.SymbolSet(symbol, symbol);
        symbol = token.symbol;
        const Spec.SymbolSet skip = Spec.skip;
        symbol = Spec.eof;
      }))
{
  alias Token = Spec.Token;
  alias Symbol = Spec.Symbol;
  alias SymbolSet = Spec.SymbolSet;
  const skip = Spec.skip;
  const eof = Spec.eof;
  bool err = false;
  // list of all tokens, including whitespace and comments.
  // Must end in `eof` token, and `eof` must not be in `skip`.
  Token[] tokens;
private:
  size_t pos = 0;
  size_t maxPos = 0;
  // indices of all tokens that are not in `skip`.
  size_t[] tokenPos;
public:
  this(Token[] tokens) {
    this.tokens = tokens;
    err = false;
    pos = 0;
  }

  T parse(T = void)(T delegate() @safe action, size_t start, size_t end) {
    auto saveErr = err;
    auto savePos = pos;
    auto saveMaxpos = maxPos;
    auto saveTokenPos = tokenPos;
    scope (exit) {
      maxPos = saveMaxpos;
      pos = savePos;
      err = saveErr;
      tokenPos = saveTokenPos;
    }
    for (auto i = start; i <= end; i++) {
      if (!skip.contains(tokens[i].symbol)) {
        tokenPos ~= i;
      }
    }
    pos = 0;
    maxPos = tokenPos.length - 1;
    tokenPos ~= tokens.length - 1; // eof marker
    err = false;
    return action();
  }

  T parse(T = void)(T delegate() @safe action) {
    return parse(action, 0, tokens.length - 1);
  }

  @property Token current() {
    return tokens[tokenPos[pos]];
  }

  @property Token next() {
    if (pos < tokenPos.length)
      return tokens[tokenPos[pos + 1]];
    else
      return tokens[$ - 1]; // eof
  }

  Token peek(size_t n) {
    if (pos + n < tokenPos.length)
      return tokens[tokenPos[pos + 1]];
    else
      return tokens[$ - 1]; // eof
  }

  @property size_t currentPos() {
    return tokenPos[pos];
  }

  @property bool ok() {
    return !err;
  }

  void fail() {
    err = true;
  }

  Mark mark() {
    return Mark(err, pos);
  }

  void reset(Mark marker) {
    err = marker.err;
    pos = marker.pos;
  }

  void advance() {
    // There is an eof token at maxPos+1, so advancing
    // stops at that token.
    if (pos <= maxPos)
      pos++;
  }

  void back() {
    pos--;
  }

  Token token(size_t at) {
    return tokens[tokenPos[at]];
  }

  void consume(T)(T value) {
    // do nothing
  }

  bool opt(lazy void action) {
    if (err)
      return false;
    auto save = pos;
    action();
    bool result = !err;
    if (err)
      pos = save;
    err = false;
    return result;
  }

  bool opt(void delegate() @safe action) {
    if (err)
      return false;
    auto save = pos;
    action();
    if (err)
      pos = save;
    bool result = !err;
    err = false;
    return result;
  }

  int alt(void delegate() @safe[] actions...) {
    if (err)
      return -1;
    int result = 0;
    auto save = pos;
    foreach (action; actions) {
      action();
      if (!err)
        return result;
      pos = save;
      result++;
      err = false;
    }
    err = true;
    return -1;
  }

  void seq(void delegate() @safe[] actions...) {
    if (err)
      return;
    auto save = pos;
    foreach (action; actions) {
      if (err)
        break;
      action();
    }
    if (err)
      pos = save;
  }

  void sym(Symbol s) {
    if (err)
      return;
    if (current.symbol == s)
      advance();
    else
      err = true;
  }

  void sym(Symbol[] slist...) {
    if (err)
      return;
    auto save = pos;
    foreach (s; slist) {
      if (current.symbol == s)
        advance();
      else {
        err = true;
        pos = save;
        return;
      }
    }
  }

  void sym(SymbolSet set) {
    if (err)
      return;
    if (set.contains(current.symbol))
      advance();
    else
      err = true;
  }

  void except(SymbolSet set) {
    if (err)
      return;
    if (set.contains(current.symbol))
      err = true;
    else
      advance();
  }

  void except(Symbol s) {
    if (err)
      return;
    if (current.symbol == s)
      err = true;
    else
      advance();
  }

  void match(lazy void action) {
    if (err)
      return;
    auto save = pos;
    action();
    pos = save;
  }

  void match(void delegate() @safe action) {
    if (err)
      return;
    auto save = pos;
    action();
    pos = save;
  }

  void nomatch(lazy void action) {
    if (err)
      return;
    auto save = pos;
    action();
    pos = save;
    err = !err;
  }

  void nomatch(void delegate() @safe action) {
    if (err)
      return;
    auto save = pos;
    action();
    pos = save;
    err = !err;
  }

  void skipUntil(Symbol s) {
    while (pos <= maxPos && current.symbol != s) {
      advance();
    }
  }

  void skipUntil(const SymbolSet set) {
    while (pos <= maxPos && !set.contains(current.symbol)) {
      advance();
    }
  }

}
