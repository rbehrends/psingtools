import std.file;
import std.stdio;
import std.range;
import std.string;
import std.algorithm;

import scanner, cpp_parser;

@safe:

struct FileList
{
  string[] cFiles;
  string[] hFiles;
  string[] cppFiles;
}

SourceFile[string] sources;
string[] classNames;
bool[string] isClassName;


@trusted
private string[] walkDir(string path) {
  return dirEntries(path, SpanMode.depth).map!(f => f.name).array;
}

private FileList listFiles(string path)
{
  bool excludeFiles(string path) {
    if (path.indexOf("/omalloc/") >= 0)
      return false;
    return true;
  }
  auto files = walkDir(path).filter!(excludeFiles);
  auto cFiles = files.filter!(f => f.endsWith(".c")).array;
  auto hFiles = files.filter!(f => f.endsWith(".h")).array;
  auto cppFiles = files.filter!(f =>
    f.endsWith(".cc") || f.endsWith(".cpp")).array;
  return FileList(cFiles, hFiles, cppFiles);
}

void scanAllFiles(const ref FileList files) {
  foreach (name; files.cFiles ~ files.hFiles ~ files.cppFiles) {
    sources[name] = scanFile(name);
  }
}

void findClassNames() {
  foreach (string name, SourceFile source; sources) {
    auto parser = new CppParser(source.tokens);
    classNames ~= parser.classNames();
  }
  classNames = classNames.sort().uniq().array;
  foreach (className; classNames) {
    isClassName[className] = true;
  }
}

void rewriteFiles() {
  foreach (string name, SourceFile source; sources) {
    auto tokens = source.tokens;
    auto parser = new CppParser(tokens);
    auto segments = parser.segments();
    bool modified = false;
    foreach (segment; segments) {
      Declaration decl = parser.parseSegment(segment, isClassName);
      if (decl is null) continue;
      if (decl.is_const) continue;
      if (segment.depth > 0 && !decl.is_extern && !decl.is_static)
        continue;
      // Actual rewrite
      if (decl.is_static) {
        auto pos = decl.static_pos;
        tokens[pos].text = "";
        if (tokens[pos+1].symbol == SymWS)
          tokens[pos+1].text = "";
      }
      if (decl.is_extern) {
        auto pos = decl.extern_pos;
        tokens[pos].text = "";
        if (tokens[pos+1].symbol == SymWS)
          tokens[pos+1].text = "";
      }
      auto pos = segment.start;
      while (skip.contains(tokens[pos].symbol)) {
        pos++;
      }
      string str;
      if (decl.is_class) {
        if (decl.is_extern)
          str = "EXTERN_INST_VAR";
        else if (decl.is_static)
          str = "STATIC_INST_VAR";
        else
          str = "INST_VAR";
      } else {
        if (decl.is_extern)
          str = "EXTERN_VAR";
        else if (decl.is_static)
          str = "STATIC_VAR";
        else
          str = "VAR";
      }
      tokens[pos].text = str ~ " " ~ tokens[pos].text;
      modified = true;
    }
    if (modified) {
      string data = "";
      foreach (token; tokens) {
        data ~= token.text;
      }
      // writeln("=== ", name);
      // writeln(data);
      std.file.write(name ~ ".tmp", data);
      std.file.rename(name ~ ".tmp", name);
    }
  }
}

void main()
{
  auto files = listFiles("../singular");
  scanAllFiles(files);
  findClassNames();
  rewriteFiles();
}
