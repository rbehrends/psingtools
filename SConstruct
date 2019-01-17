import os

# Command line options

AddOption("--opt", dest="opt",
  action="store_true",
  help="optimized build")
AddOption("--force", dest="force",
  action="store_true",
  help="force rebuild")
AddOption("--without-re2c", dest="without-re2c",
  action="store_true",
  help="do not use re2c")

SetOption("num_jobs", 4)

# Configure the environment

if GetOption("opt"):
  dflags="-g -O -release"
else:
  dflags="-g"

env = Environment(ENV={"PATH": os.environ["PATH"]})
env["DFLAGS"] = dflags.split()
env["DLINKFLAGS"] = "-g"
env["OBJPREFIX"] = "#/build/"
env["PROGPREFIX"] = "#/bin/"
env["DPATH"] = [ "#/src", "#/gen" ]

# More readable commands

for var in ["DCOM", "DLINKCOM", "SHDLINKCOM"]:
  env[var] = env[var].replace("-of$TARGET", "-of=$TARGET", 1)

# Re2c support; convert "unsigned int" -> "uint"

re2c = Builder(action =
  "re2c -o $TARGET $SOURCES\ntools/subst 'unsigned int' uint $TARGET",
  src_suffix = ".re", suffix = ".d", prefix = "#/gen/")
env.Append(BUILDERS = { "Re2c": re2c })

# Rules

if not GetOption("without-re2c"):
  env.Program("#/tools/subst", "#/tools/subst.d",
    PROGPREFIX="", DFLAGS="", DPATH="", OBJPREFIX="")
  env.Re2c(Glob("#/src/*.re"))
  env.Depends("#/gen/scanner.d", "#/tools/subst")
env.Program("refit", Glob("#/src/*.d") + Glob("#/gen/*.d"))

# Figure out intermediate and final targets for "--force"

targets = Flatten([ env.Glob(pat, ondisk=False)
  for pat in [ "#/bin/main", "#/build/*.o", "#/gen/*.d" ] ])
if GetOption("force"):
  AlwaysBuild(targets)

