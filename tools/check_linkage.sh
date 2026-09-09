#!/usr/bin/env bash
# Build the static archive the same way the package does, then compile and run a
# CVODE dense example against it. Fast sanity check that the vendored subset links
# and solves. Run from the package root.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT/src"

CC="$(R CMD config CC)"
CFLAGS="$(R CMD config CFLAGS) $(R CMD config CPICFLAGS)"
CPPF="-I../inst/include -Isundials/sundials -DNDEBUG"

echo ">> compiling ${ROOT##*/} SUNDIALS objects"
mapfile -t OBJS < <(sed -n 's/^  \(sundials\/.*\)\.o.*/\1/p' sundials_srcs.mk)
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
for o in "${OBJS[@]}"; do
  mkdir -p "$tmp/$(dirname "$o")"
  $CC $CFLAGS $CPPF -c "$o.c" -o "$tmp/$o.o"
done
ar rcs "$tmp/libsundials.a" $(printf "%s.o\n" "${OBJS[@]/#/$tmp/}")
ranlib "$tmp/libsundials.a"
echo ">> archive: $(du -h "$tmp/libsundials.a" | cut -f1)"

cat > "$tmp/ex.c" <<'C'
/* y' = -y, y(0)=1 ; check y(1) ~ exp(-1) via CVODE BDF + dense linear solver */
#include <stdio.h>
#include <math.h>
#include <cvode/cvode.h>
#include <nvector/nvector_serial.h>
#include <sunmatrix/sunmatrix_dense.h>
#include <sunlinsol/sunlinsol_dense.h>

static int rhs(sunrealtype t, N_Vector y, N_Vector yd, void *u) {
  (void)t; (void)u;
  NV_Ith_S(yd, 0) = -NV_Ith_S(y, 0);
  return 0;
}
int main(void) {
  SUNContext ctx;
  if (SUNContext_Create(SUN_COMM_NULL, &ctx)) return 2;
  N_Vector y = N_VNew_Serial(1, ctx);
  NV_Ith_S(y, 0) = 1.0;
  void *cv = CVodeCreate(CV_BDF, ctx);
  CVodeInit(cv, rhs, 0.0, y);
  CVodeSStolerances(cv, 1e-10, 1e-12);
  SUNMatrix A = SUNDenseMatrix(1, 1, ctx);
  SUNLinearSolver LS = SUNLinSol_Dense(y, A, ctx);
  CVodeSetLinearSolver(cv, LS, A);
  sunrealtype tret;
  int flag = CVode(cv, 1.0, y, &tret, CV_NORMAL);
  double got = NV_Ith_S(y, 0), want = exp(-1.0);
  printf("flag=%d y(1)=%.12f exp(-1)=%.12f err=%.2e\n", flag, got, want, fabs(got - want));
  CVodeFree(&cv); SUNLinSolFree(LS); SUNMatDestroy(A); N_VDestroy(y); SUNContext_Free(&ctx);
  return (flag == CV_SUCCESS && fabs(got - want) < 1e-6) ? 0 : 1;
}
C

echo ">> linking + running example"
$CC $CFLAGS -I"$ROOT/inst/include" "$tmp/ex.c" "$tmp/libsundials.a" -lm -o "$tmp/ex"
"$tmp/ex"
echo ">> OK"
