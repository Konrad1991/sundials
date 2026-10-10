library(tinytest)
exit_if_not(requireNamespace("Rcpp", quietly = TRUE))

# CVODE on the 1-D heat equation y' = A y, A = tridiag(1, -2, 1), with the
# dense, band and SPGMR (matrix-free) linear solvers. Reference: eigen
# decomposition of the symmetric A.
code <- '
// [[Rcpp::depends(sundials)]]
#include <Rcpp.h>
#include <cvode/cvode.h>
#include <nvector/nvector_serial.h>
#include <sunmatrix/sunmatrix_dense.h>
#include <sunmatrix/sunmatrix_band.h>
#include <sunlinsol/sunlinsol_dense.h>
#include <sunlinsol/sunlinsol_band.h>
#include <sunlinsol/sunlinsol_spgmr.h>

static int heat(sunrealtype, N_Vector y, N_Vector yd, void*) {
  const sunindextype n = NV_LENGTH_S(y);
  const sunrealtype* u = NV_DATA_S(y);
  sunrealtype* du = NV_DATA_S(yd);
  for (sunindextype i = 0; i < n; i++) {
    const sunrealtype l = i > 0 ? u[i - 1] : 0.0;
    const sunrealtype r = i < n - 1 ? u[i + 1] : 0.0;
    du[i] = l - 2.0 * u[i] + r;
  }
  return 0;
}

// [[Rcpp::export]]
Rcpp::NumericVector cvode_heat(Rcpp::NumericVector y0, double tout, std::string solver) {
  SUNContext ctx;
  if (SUNContext_Create(SUN_COMM_NULL, &ctx)) Rcpp::stop("SUNContext_Create failed");
  const sunindextype n = y0.size();
  N_Vector y = N_VNew_Serial(n, ctx);
  for (sunindextype i = 0; i < n; i++) NV_Ith_S(y, i) = y0[i];
  void* cv = CVodeCreate(CV_BDF, ctx);
  CVodeInit(cv, heat, 0.0, y);
  CVodeSStolerances(cv, 1e-10, 1e-12);
  CVodeSetMaxNumSteps(cv, 100000);
  SUNMatrix A = NULL;
  SUNLinearSolver LS = NULL;
  if (solver == "dense") {
    A = SUNDenseMatrix(n, n, ctx);
    LS = SUNLinSol_Dense(y, A, ctx);
  } else if (solver == "band") {
    A = SUNBandMatrix(n, 1, 1, ctx);
    LS = SUNLinSol_Band(y, A, ctx);
  } else {
    LS = SUNLinSol_SPGMR(y, SUN_PREC_NONE, 0, ctx);
  }
  CVodeSetLinearSolver(cv, LS, A);
  sunrealtype tret;
  const int flag = CVode(cv, tout, y, &tret, CV_NORMAL);
  Rcpp::NumericVector out(n);
  for (sunindextype i = 0; i < n; i++) out[i] = NV_Ith_S(y, i);
  CVodeFree(&cv);
  SUNLinSolFree(LS);
  if (A) SUNMatDestroy(A);
  N_VDestroy(y);
  SUNContext_Free(&ctx);
  if (flag < 0) Rcpp::stop("CVode failed with flag %d", flag);
  return out;
}
'
env <- new.env()
Rcpp::sourceCpp(code = code, env = env)

n <- 20
A <- diag(-2, n)
A[cbind(1:(n - 1), 2:n)] <- 1
A[cbind(2:n, 1:(n - 1))] <- 1
y0 <- sin(pi * (1:n) / (n + 1)) + 0.5 * sin(3 * pi * (1:n) / (n + 1))
tout <- 2
e <- eigen(A, symmetric = TRUE)
ref <- drop(e$vectors %*% (exp(e$values * tout) * crossprod(e$vectors, y0)))

for (s in c("dense", "band", "spgmr")) {
  expect_equal(env$cvode_heat(y0, tout, s), ref, tolerance = 1e-6, info = s)
}
