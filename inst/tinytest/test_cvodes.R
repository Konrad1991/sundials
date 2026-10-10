library(tinytest)
exit_if_not(requireNamespace("Rcpp", quietly = TRUE))

# CVODES forward sensitivity on y' = -p y, y(0) = 1:
#   y = exp(-p t),  dy/dp = -t exp(-p t)
# Also guards the link: cvode.o and cvodes.o define the same symbols.
code <- '
// [[Rcpp::depends(sundials)]]
#include <Rcpp.h>
#include <cvodes/cvodes.h>
#include <nvector/nvector_serial.h>
#include <sunmatrix/sunmatrix_dense.h>
#include <sunlinsol/sunlinsol_dense.h>

static int decay(sunrealtype, N_Vector y, N_Vector yd, void* data) {
  const sunrealtype p = *static_cast<sunrealtype*>(data);
  NV_Ith_S(yd, 0) = -p * NV_Ith_S(y, 0);
  return 0;
}

// [[Rcpp::export]]
Rcpp::NumericMatrix cvodes_sens(Rcpp::NumericVector times, double p_in) {
  SUNContext ctx;
  if (SUNContext_Create(SUN_COMM_NULL, &ctx)) Rcpp::stop("SUNContext_Create failed");
  sunrealtype p = p_in;
  sunrealtype pbar = p_in;
  N_Vector y = N_VNew_Serial(1, ctx);
  NV_Ith_S(y, 0) = 1.0;
  void* cv = CVodeCreate(CV_BDF, ctx);
  CVodeInit(cv, decay, 0.0, y);
  CVodeSStolerances(cv, 1e-10, 1e-12);
  CVodeSetUserData(cv, &p);
  SUNMatrix A = SUNDenseMatrix(1, 1, ctx);
  SUNLinearSolver LS = SUNLinSol_Dense(y, A, ctx);
  CVodeSetLinearSolver(cv, LS, A);

  N_Vector* yS = N_VCloneVectorArray(1, y);
  N_VConst(0.0, yS[0]);
  CVodeSensInit1(cv, 1, CV_SIMULTANEOUS, NULL, yS);
  CVodeSetSensParams(cv, &p, &pbar, NULL);
  CVodeSensEEtolerances(cv);

  Rcpp::NumericMatrix out(times.size(), 2);
  int flag = CV_SUCCESS;
  sunrealtype tret;
  for (R_xlen_t i = 0; i < times.size() && flag >= 0; i++) {
    flag = CVode(cv, times[i], y, &tret, CV_NORMAL);
    if (flag >= 0) flag = CVodeGetSens(cv, &tret, yS);
    out(i, 0) = NV_Ith_S(y, 0);
    out(i, 1) = NV_Ith_S(yS[0], 0);
  }
  N_VDestroyVectorArray(yS, 1);
  CVodeFree(&cv);
  SUNLinSolFree(LS);
  SUNMatDestroy(A);
  N_VDestroy(y);
  SUNContext_Free(&ctx);
  if (flag < 0) Rcpp::stop("CVODES failed with flag %d", flag);
  return out;
}
'
env <- new.env()
Rcpp::sourceCpp(code = code, env = env)
times <- c(0.5, 1, 2)
p <- 2
res <- env$cvodes_sens(times, p)
expect_equal(res[, 1], exp(-p * times), tolerance = 1e-6)
expect_equal(res[, 2], -times * exp(-p * times), tolerance = 1e-4)
