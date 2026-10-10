library(tinytest)
exit_if_not(requireNamespace("Rcpp", quietly = TRUE))

# IDA on the index-1 DAE  y1' = -y1,  0 = y1 + y2 - 1
# -> y1 = exp(-t), y2 = 1 - exp(-t)
code <- '
// [[Rcpp::depends(sundials)]]
#include <Rcpp.h>
#include <ida/ida.h>
#include <nvector/nvector_serial.h>
#include <sunmatrix/sunmatrix_dense.h>
#include <sunlinsol/sunlinsol_dense.h>

static int res(sunrealtype, N_Vector y, N_Vector yp, N_Vector r, void*) {
  NV_Ith_S(r, 0) = NV_Ith_S(yp, 0) + NV_Ith_S(y, 0);
  NV_Ith_S(r, 1) = NV_Ith_S(y, 0) + NV_Ith_S(y, 1) - 1.0;
  return 0;
}

// [[Rcpp::export]]
Rcpp::NumericMatrix ida_dae(Rcpp::NumericVector times) {
  SUNContext ctx;
  if (SUNContext_Create(SUN_COMM_NULL, &ctx)) Rcpp::stop("SUNContext_Create failed");
  N_Vector y = N_VNew_Serial(2, ctx);
  N_Vector yp = N_VNew_Serial(2, ctx);
  NV_Ith_S(y, 0) = 1.0; NV_Ith_S(y, 1) = 0.0;
  NV_Ith_S(yp, 0) = -1.0; NV_Ith_S(yp, 1) = 1.0;
  void* ida = IDACreate(ctx);
  IDAInit(ida, res, 0.0, y, yp);
  IDASStolerances(ida, 1e-10, 1e-12);
  SUNMatrix A = SUNDenseMatrix(2, 2, ctx);
  SUNLinearSolver LS = SUNLinSol_Dense(y, A, ctx);
  IDASetLinearSolver(ida, LS, A);
  Rcpp::NumericMatrix out(times.size(), 2);
  int flag = IDA_SUCCESS;
  sunrealtype tret;
  for (R_xlen_t i = 0; i < times.size() && flag >= 0; i++) {
    flag = IDASolve(ida, times[i], &tret, y, yp, IDA_NORMAL);
    out(i, 0) = NV_Ith_S(y, 0);
    out(i, 1) = NV_Ith_S(y, 1);
  }
  IDAFree(&ida);
  SUNLinSolFree(LS);
  SUNMatDestroy(A);
  N_VDestroy(y);
  N_VDestroy(yp);
  SUNContext_Free(&ctx);
  if (flag < 0) Rcpp::stop("IDASolve failed with flag %d", flag);
  return out;
}
'
env <- new.env()
Rcpp::sourceCpp(code = code, env = env)
times <- c(0.5, 1, 2, 5)
res <- env$ida_dae(times)
expect_equal(res[, 1], exp(-times), tolerance = 1e-6)
expect_equal(res[, 2], 1 - exp(-times), tolerance = 1e-6)
