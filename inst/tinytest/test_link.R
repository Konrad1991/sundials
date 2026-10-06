library(tinytest)

libdir <- system.file("lib", .Platform$r_arch, package = "sundials")
incdir <- system.file("include", package = "sundials")

# --- the shipped artefacts are where LdFlags()/LinkingTo expect them ---
expect_true(nzchar(libdir))
expect_true(file.exists(file.path(libdir, "libsundials.a")))
expect_true(file.exists(file.path(incdir, "sundials", "sundials_config.h")))
expect_true(file.exists(file.path(incdir, "cvode", "cvode.h")))
expect_true(file.exists(file.path(incdir, "idas", "idas.h")))
expect_true(file.exists(file.path(incdir, "arkode", "arkode_arkstep.h")))

ld <- sundials::LdFlags()
expect_true(grepl("-lsundials", ld, fixed = TRUE))
expect_true(grepl("-L", ld, fixed = TRUE))

# --- link and run a solver against the archive via inlineCxxPlugin ---
# sourceCpp goes through R CMD SHLIB, so R's compiler and flags (incl.
# sanitizer builds) are used, and the plugin itself is exercised.
exit_if_not(requireNamespace("Rcpp", quietly = TRUE))

# Robertson (stiff), as in SUNDIALS' cvRoberts_dns; reference made once with
# deSolve::lsode by development/make_robertson_ref.R
ref <- read.csv("robertson_ref.csv")

code <- '
// [[Rcpp::depends(sundials)]]
#include <Rcpp.h>
#include <cvode/cvode.h>
#include <nvector/nvector_serial.h>
#include <sunmatrix/sunmatrix_dense.h>
#include <sunlinsol/sunlinsol_dense.h>

static int robertson(sunrealtype, N_Vector y, N_Vector yd, void*) {
  sunrealtype y1 = NV_Ith_S(y, 0), y2 = NV_Ith_S(y, 1), y3 = NV_Ith_S(y, 2);
  NV_Ith_S(yd, 0) = -0.04 * y1 + 1e4 * y2 * y3;
  NV_Ith_S(yd, 2) = 3e7 * y2 * y2;
  NV_Ith_S(yd, 1) = -NV_Ith_S(yd, 0) - NV_Ith_S(yd, 2);
  return 0;
}

// [[Rcpp::export]]
Rcpp::NumericMatrix cvode_robertson(Rcpp::NumericVector times) {
  SUNContext ctx;
  if (SUNContext_Create(SUN_COMM_NULL, &ctx)) Rcpp::stop("SUNContext_Create failed");
  N_Vector y = N_VNew_Serial(3, ctx);
  NV_Ith_S(y, 0) = 1.0; NV_Ith_S(y, 1) = 0.0; NV_Ith_S(y, 2) = 0.0;
  void* cv = CVodeCreate(CV_BDF, ctx);
  CVodeInit(cv, robertson, 0.0, y);
  CVodeSStolerances(cv, 1e-10, 1e-16);
  SUNMatrix A = SUNDenseMatrix(3, 3, ctx);
  SUNLinearSolver LS = SUNLinSol_Dense(y, A, ctx);
  CVodeSetLinearSolver(cv, LS, A);
  CVodeSetMaxNumSteps(cv, 100000);

  Rcpp::NumericMatrix out(times.size(), 3);
  int flag = CV_SUCCESS;
  sunrealtype tret;
  for (R_xlen_t i = 0; i < times.size() && flag == CV_SUCCESS; i++) {
    flag = CVode(cv, times[i], y, &tret, CV_NORMAL);
    for (int j = 0; j < 3; j++) out(i, j) = NV_Ith_S(y, j);
  }
  CVodeFree(&cv);
  SUNLinSolFree(LS);
  SUNMatDestroy(A);
  N_VDestroy(y);
  SUNContext_Free(&ctx);
  if (flag != CV_SUCCESS) Rcpp::stop("CVode failed with flag %d", flag);
  return out;
}
'

env <- new.env()
Rcpp::sourceCpp(code = code, env = env)
res <- env$cvode_robertson(ref$t)
# per component, relative: y2 is ~1e-7 and would vanish in a joint comparison
expect_equal(res[, 1], ref$y1, tolerance = 1e-6)
expect_equal(res[, 2], ref$y2, tolerance = 1e-6)
expect_equal(res[, 3], ref$y3, tolerance = 1e-6)
