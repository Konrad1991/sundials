#!/usr/bin/env bash
# Vendor a SUNDIALS release into this package.
#
# Reproducible: downloads the release tarball, runs `cmake` in configure-only
# mode to generate the two headers CMake owns (sundials_config.h,
# sundials_export.h), then copies the C sources + headers for the pure-C
# subset (no Fortran, MPI, GPU, or external-TPL modules) into src/ and
# inst/include/. The compiled-source list is read back from
# compile_commands.json, so a version bump needs no hand editing here.
#
# Usage:  tools/vendor.sh [version]     (default below)
set -euo pipefail

VERSION="${1:-7.9.0}"
PKG_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

url="https://github.com/LLNL/sundials/releases/download/v${VERSION}/sundials-${VERSION}.tar.gz"
echo ">> downloading $url"
curl -fsSL -o "$WORK/sundials.tar.gz" "$url"
tar xzf "$WORK/sundials.tar.gz" -C "$WORK"
SRC_TREE="$WORK/sundials-${VERSION}"

# NOTE: CVODE and IDA are not compiled. CVODES/IDAS define the same symbols
# (supersets, same API), and both in one static archive fail to link with
# "multiple definition". Their headers are still shipped, so code including
# <cvode/cvode.h> / <ida/ida.h> links against CVODES / IDAS.
echo ">> cmake configure (headers + source list only, no build)"
BUILD="$WORK/build"
mkdir -p "$BUILD"
cmake -S "$SRC_TREE" -B "$BUILD" \
  -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
  -DBUILD_SHARED_LIBS=OFF -DBUILD_STATIC_LIBS=ON \
  -DEXAMPLES_ENABLE_C=OFF -DEXAMPLES_ENABLE_CXX=OFF -DBUILD_TESTING=OFF \
  -DBUILD_FORTRAN_MODULE_INTERFACE=OFF \
  -DSUNDIALS_INDEX_SIZE=64 \
  -DBUILD_ARKODE=ON -DBUILD_CVODE=OFF -DBUILD_CVODES=ON \
  -DBUILD_IDA=OFF -DBUILD_IDAS=ON -DBUILD_KINSOL=ON \
  -DSUNDIALS_ENABLE_PROFILING=OFF -DSUNDIALS_LOGGING_LEVEL=0 \
  >/dev/null

echo ">> resetting src/sundials and inst/include"
rm -rf "$PKG_ROOT/src/sundials" "$PKG_ROOT/inst/include"
mkdir -p "$PKG_ROOT/src/sundials" "$PKG_ROOT/inst/include"

echo ">> copying public headers -> inst/include"
cp -R "$SRC_TREE/include/." "$PKG_ROOT/inst/include/"
# the two headers CMake generates from *.in
cp "$BUILD/include/sundials/sundials_config.h" "$PKG_ROOT/inst/include/sundials/"
cp "$BUILD/include/sundials/sundials_export.h" "$PKG_ROOT/inst/include/sundials/"
rm -f "$PKG_ROOT/inst/include/sundials/sundials_config.in"

# SUNDIALS calls its own deprecated API internally; R CMD check counts the
# resulting -Wdeprecated-declarations as significant, and -Wno-* flags are not
# portable. Only our own build defines the guard, so dependents keep the warnings.
echo ">> patching sundials_config.h (deprecation attribute off for own build)"
python3 - "$PKG_ROOT/inst/include/sundials/sundials_config.h" <<'PY'
import sys
path = sys.argv[1]
anchor = "#ifndef SUNDIALS_DEPRECATED_MSG\n"
patch = ("/* R package 'sundials': silence deprecation inside the vendored build */\n"
         "#if defined(SUNDIALS_R_NO_DEPRECATION_WARNINGS) && !defined(SUNDIALS_DEPRECATED_MSG)\n"
         "#  define SUNDIALS_DEPRECATED_MSG(msg)\n"
         "#endif\n\n")
src = open(path).read()
if src.count(anchor) != 1:
    sys.exit("sundials_config.h: deprecation anchor not found exactly once")
open(path, "w").write(src.replace(anchor, patch + anchor))
PY

echo ">> extracting compiled-source list from compile_commands.json"
mapfile -t SRCS < <(python3 - "$BUILD/compile_commands.json" "$SRC_TREE/src" <<'PY'
import json, os, sys
cc, base = sys.argv[1], os.path.abspath(sys.argv[2]) + "/"
seen = sorted({e["file"][len(base):] for e in json.load(open(cc))
               if e["file"].startswith(base) and e["file"].endswith(".c")})
print("\n".join(seen))
PY
)
echo "   ${#SRCS[@]} sources"

echo ">> copying sources + their sibling impl headers -> src/sundials"
declare -A DIRS
for rel in "${SRCS[@]}"; do
  d="$(dirname "$rel")"
  DIRS["$d"]=1
  mkdir -p "$PKG_ROOT/src/sundials/$d"
  cp "$SRC_TREE/src/$rel" "$PKG_ROOT/src/sundials/$rel"
done
# private headers live next to the sources (arkode also ships *.def tables)
for d in "${!DIRS[@]}"; do
  shopt -s nullglob
  for f in "$SRC_TREE/src/$d"/*.h "$SRC_TREE/src/$d"/*.def; do
    cp "$f" "$PKG_ROOT/src/sundials/$d/"
  done
  shopt -u nullglob
done
# the core src/sundials dir ships private headers (some in header-only subdirs
# like stl/) that sources elsewhere include as "sundials_*.h" or "stl/*.h"
( cd "$SRC_TREE/src/sundials" && find . -name '*.h' -print0 \
  | while IFS= read -r -d '' h; do
      mkdir -p "$PKG_ROOT/src/sundials/sundials/$(dirname "$h")"
      cp "$h" "$PKG_ROOT/src/sundials/sundials/$h"
    done )

# the object list is inlined rather than include'd: R CMD check warns about
# extra files like *.mk in src/
echo ">> writing src/Makevars and src/Makevars.win"
{
  echo "SUNDIALS_OBJECTS = \\"
  n=${#SRCS[@]}
  for i in "${!SRCS[@]}"; do
    o="sundials/${SRCS[$i]%.c}.o"
    if [ "$i" -lt $((n - 1)) ]; then echo "  $o \\"; else echo "  $o"; fi
  done
} > "$WORK/objects.mk"
awk -v objs="$WORK/objects.mk" '
  $0 == "@SUNDIALS_OBJECTS@" { while ((getline l < objs) > 0) print l; next }
  { print }' "$PKG_ROOT/tools/Makevars.in" > "$PKG_ROOT/src/Makevars"
cp "$PKG_ROOT/src/Makevars" "$PKG_ROOT/src/Makevars.win"

echo ">> license files"
cp "$SRC_TREE/LICENSE" "$PKG_ROOT/inst/SUNDIALS-LICENSE"
cp "$SRC_TREE/NOTICE"  "$PKG_ROOT/inst/SUNDIALS-NOTICE"

echo "$VERSION" > "$PKG_ROOT/tools/SUNDIALS_VERSION"
echo ">> done: SUNDIALS ${VERSION}, ${#SRCS[@]} C sources vendored"
