library(tinytest)

libdir <- system.file("lib", .Platform$r_arch, package = "sundials")
incdir <- system.file("include", package = "sundials")

# --- always: the shipped artefacts are where LdFlags()/LinkingTo expect them ---
expect_true(nzchar(libdir))
expect_true(file.exists(file.path(libdir, "libsundials.a")))
expect_true(file.exists(file.path(incdir, "sundials", "sundials_config.h")))
expect_true(file.exists(file.path(incdir, "cvode", "cvode.h")))
expect_true(file.exists(file.path(incdir, "idas", "idas.h")))
expect_true(file.exists(file.path(incdir, "arkode", "arkode_arkstep.h")))

ld <- sundials::LdFlags()
expect_true(grepl("-lsundials", ld, fixed = TRUE))
expect_true(grepl("-L", ld, fixed = TRUE))

# --- at home / CI only: actually link and run a solver against the archive ---
if (at_home()) {
  CC <- Sys.getenv("CC", unset = "")
  if (!nzchar(CC)) CC <- tryCatch(
    system2(file.path(R.home("bin"), "R"), c("CMD", "config", "CC"),
            stdout = TRUE),
    error = function(e) "")
  have_cc <- nzchar(CC) && nzchar(Sys.which(sub(" .*", "", CC)))

  if (have_cc) {
    wd <- tempfile("sundials-link-"); dir.create(wd)
    on.exit(unlink(wd, recursive = TRUE), add = TRUE)
    src <- file.path(wd, "ex.c")
    writeLines(c(
      "#include <math.h>",
      "#include <cvode/cvode.h>",
      "#include <nvector/nvector_serial.h>",
      "#include <sunmatrix/sunmatrix_dense.h>",
      "#include <sunlinsol/sunlinsol_dense.h>",
      "static int rhs(sunrealtype t, N_Vector y, N_Vector yd, void *u){",
      "  (void)t;(void)u; NV_Ith_S(yd,0) = -NV_Ith_S(y,0); return 0; }",
      "int main(void){",
      "  SUNContext c; if (SUNContext_Create(SUN_COMM_NULL,&c)) return 2;",
      "  N_Vector y = N_VNew_Serial(1,c); NV_Ith_S(y,0)=1.0;",
      "  void *cv = CVodeCreate(CV_BDF,c);",
      "  CVodeInit(cv,rhs,0.0,y); CVodeSStolerances(cv,1e-10,1e-12);",
      "  SUNMatrix A = SUNDenseMatrix(1,1,c);",
      "  SUNLinearSolver LS = SUNLinSol_Dense(y,A,c);",
      "  CVodeSetLinearSolver(cv,LS,A);",
      "  sunrealtype tr; int f = CVode(cv,1.0,y,&tr,CV_NORMAL);",
      "  double e = fabs(NV_Ith_S(y,0) - exp(-1.0));",
      "  CVodeFree(&cv); SUNLinSolFree(LS); SUNMatDestroy(A);",
      "  N_VDestroy(y); SUNContext_Free(&c);",
      "  return (f==CV_SUCCESS && e < 1e-6) ? 0 : 1; }"
    ), src)

    cflags <- tryCatch(
      system2(file.path(R.home("bin"), "R"), c("CMD", "config", "CFLAGS"),
              stdout = TRUE), error = function(e) "")
    exe <- file.path(wd, "ex")
    ld_parts <- c(paste0("-L", shQuote(normalizePath(libdir))), "-lsundials", "-lm")
    status <- tryCatch(
      system2(sub(" .*", "", CC),
              c(strsplit(cflags, " ")[[1]], paste0("-I", shQuote(incdir)),
                shQuote(src), "-o", shQuote(exe), ld_parts),
              stdout = TRUE, stderr = TRUE),
      error = function(e) { attr(e, "failed") <- TRUE; e })

    if (!inherits(status, "error") && file.exists(exe)) {
      rc <- system2(exe)
      expect_equal(rc, 0L, info = "CVODE dense solve against libsundials.a")
    }
  }
}
