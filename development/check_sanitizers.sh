#!/usr/bin/env bash
# R CMD check in R-hub's sanitizer containers (the images rhub_check() uses).
# Sanitizer findings do not change the check status, so the logs are grepped.
#
# Usage (from anywhere):  development/check_sanitizers.sh [image ...]
#   default images: gcc-asan clang-ubsan
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/development/sanitizers"
if [ $# -gt 0 ]; then IMAGES=("$@"); else IMAGES=(gcc-asan clang-ubsan); fi

cd "$ROOT"
rm -f sundials_*.tar.gz
R CMD build .
TARBALL="$(ls sundials_*.tar.gz)"
mkdir -p "$OUT"

status=0
for img in "${IMAGES[@]}"; do
  echo ">> $img"
  rm -rf "$OUT/$img"
  # R CMD check --output needs an existing directory
  mkdir -p "$OUT/$img"
  # detect_leaks=0 as on CRAN; deSolve is only for development/, so suggests
  # are not forced
  docker run --rm \
    -e ASAN_OPTIONS=detect_leaks=0 \
    -e UBSAN_OPTIONS=print_stacktrace=1 \
    -e _R_CHECK_FORCE_SUGGESTS_=false \
    -v "$ROOT":/pkg:ro -v "$OUT":/out \
    "ghcr.io/r-hub/containers/$img" bash -c "
      R -q -e 'install.packages(c(\"tinytest\", \"Rcpp\"), repos = \"https://cloud.r-project.org\")' &&
      R CMD check --no-manual --output=/out/$img /pkg/$TARBALL;
      rc=\$?; chown -R $(id -u):$(id -g) /out/$img; exit \$rc" \
    || status=1

  if [ ! -f "$OUT/$img/sundials.Rcheck/00check.log" ]; then
    echo "!! $img: check did not run (no 00check.log)"
    status=1
    continue
  fi
  grep -h '^Status' "$OUT/$img/sundials.Rcheck/00check.log" || true
  if grep -rnE 'runtime error|AddressSanitizer|LeakSanitizer' "$OUT/$img"; then
    echo "!! $img: sanitizer findings above"
    status=1
  else
    echo "   $img: no sanitizer findings"
  fi
done

exit $status
