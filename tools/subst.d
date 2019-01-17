import file = std.file;
import path = std.path;
import std.string;
import std.stdio;

int main(string[] args) {
  if (args.length < 3) {
    writeln(format("usage: %s STRING REPLACEMENT FILE...",
      path.baseName(args[0])));
    return 1;
  }
  int err = 0;

  foreach (string arg; args[3 .. $]) {
    try {
      string data = file.readText(arg);
      string newdata = replace(data, args[1], args[2]);
      if (data == newdata)
        continue;
      string tmp = arg ~ ".tmp";
      file.write(tmp, newdata);
      file.rename(tmp, arg);
    } catch (file.FileException e) {
      writeln("cannot rewrite file " ~ arg);
      err = 1;
    }
  }
  return err;
}
