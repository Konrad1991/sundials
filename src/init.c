#include <R.h>
#include <Rinternals.h>
#include <R_ext/Rdynload.h>

/* This package ships only a static library (inst/lib) for other packages to
   link against; the shared object carries no routines of its own. */
void R_init_sundials(DllInfo *dll) {
  R_registerRoutines(dll, NULL, NULL, NULL, NULL);
  R_useDynamicSymbols(dll, FALSE);
}
