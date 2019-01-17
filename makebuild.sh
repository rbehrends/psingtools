#!/bin/sh
make >/dev/null
set -e
{
  cat <<'EOF'
#!/bin/sh
set -e
cd "`dirname "$0"`"
test -f with-local-dmd && . with-local-dmd
set -v
EOF
  scons -n --force --without-re2c -Q | egrep ^dmd
} > build.sh
chmod 755 build.sh
