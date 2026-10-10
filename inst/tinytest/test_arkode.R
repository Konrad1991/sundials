library(tinytest)
exit_if_not(requireNamespace("Rcpp", quietly = TRUE))

# ARKODE explicit RK on y' = -y, y(0) = 1 -> exp(-t)
code <- '
// [[Rcpp::depends(sundials)]]
#include <Rcpp.h>
#include <arkode/arkode_arkstep.h>
#include <nvector/nvector_serial.h>

static int decay(sunrealtype, N_Vector y, N_Vector yd, void*) {
  NV_Ith_S(yd, 0) = -NV_Ith_S(y, 0);
  return 0;
}

// [[Rcpp::export]]
Rcpp::NumericVector arkode_decay(Rcpp::NumericVector times) {
  SUNContext ctx;
  if (SUNContext_Create(SUN_COMM_NULL, &ctx)) Rcpp::stop("SUNContext_Create failed");
  N_Vector y = N_VNew_Serial(1, ctx);
  NV_Ith_S(y, 0) = 1.0;
  void* ark = ARKStepCreate(decay, NULL, 0.0, y, ctx);
  ARKodeSStolerances(ark, 1e-10, 1e-12);
  Rcpp::NumericVector out(times.size());
  int flag = ARK_SUCCESS;
  sunrealtype tret;
  for (R_xlen_t i = 0; i < times.size() && flag >= 0; i++) {
    flag = ARKodeEvolve(ark, times[i], y, &tret, ARK_NORMAL);
    out[i] = NV_Ith_S(y, 0);
  }
  ARKodeFree(&ark);
  N_VDestroy(y);
  SUNContext_Free(&ctx);
  if (flag < 0) Rcpp::stop("ARKodeEvolve failed with flag %d", flag);
  return out;
}
'
env <- new.env()
Rcpp::sourceCpp(code = code, env = env)
times <- c(0.5, 1, 2, 5)
expect_equal(env$arkode_decay(times), exp(-times), tolerance = 1e-7)
