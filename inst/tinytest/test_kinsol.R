library(tinytest)
exit_if_not(requireNamespace("Rcpp", quietly = TRUE))

# KINSOL Newton on  x^2 + y^2 = 4,  x = y  ->  x = y = sqrt(2)
code <- '
// [[Rcpp::depends(sundials)]]
#include <Rcpp.h>
#include <kinsol/kinsol.h>
#include <nvector/nvector_serial.h>
#include <sunmatrix/sunmatrix_dense.h>
#include <sunlinsol/sunlinsol_dense.h>

static int sys(N_Vector u, N_Vector f, void*) {
  sunrealtype x = NV_Ith_S(u, 0), y = NV_Ith_S(u, 1);
  NV_Ith_S(f, 0) = x * x + y * y - 4.0;
  NV_Ith_S(f, 1) = x - y;
  return 0;
}

// [[Rcpp::export]]
Rcpp::NumericVector kinsol_circle() {
  SUNContext ctx;
  if (SUNContext_Create(SUN_COMM_NULL, &ctx)) Rcpp::stop("SUNContext_Create failed");
  N_Vector u = N_VNew_Serial(2, ctx);
  N_Vector s = N_VNew_Serial(2, ctx);
  NV_Ith_S(u, 0) = 1.0; NV_Ith_S(u, 1) = 0.5;
  N_VConst(1.0, s);
  void* kin = KINCreate(ctx);
  KINInit(kin, sys, u);
  KINSetFuncNormTol(kin, 1e-12);
  SUNMatrix A = SUNDenseMatrix(2, 2, ctx);
  SUNLinearSolver LS = SUNLinSol_Dense(u, A, ctx);
  KINSetLinearSolver(kin, LS, A);
  int flag = KINSol(kin, u, KIN_LINESEARCH, s, s);
  Rcpp::NumericVector out = {NV_Ith_S(u, 0), NV_Ith_S(u, 1)};
  KINFree(&kin);
  SUNLinSolFree(LS);
  SUNMatDestroy(A);
  N_VDestroy(u);
  N_VDestroy(s);
  SUNContext_Free(&ctx);
  if (flag < 0) Rcpp::stop("KINSol failed with flag %d", flag);
  return out;
}
'
env <- new.env()
Rcpp::sourceCpp(code = code, env = env)
expect_equal(env$kinsol_circle(), rep(sqrt(2), 2), tolerance = 1e-8)
