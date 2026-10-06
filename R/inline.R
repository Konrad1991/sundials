# Lets other packages / sourceCpp pull in the vendored SUNDIALS with
#   // [[Rcpp::depends(sundials)]]
# Rcpp merges env$PKG_CPPFLAGS and env$PKG_LIBS from this plugin into the compile.

inlineCxxPlugin <- function(...) {
  inc <- system.file("include", package = "sundials", mustWork = TRUE)
  list(
    env = list(
      PKG_CPPFLAGS = paste0("-I", quoted_path(inc)),
      PKG_LIBS = ld_flags()
    )
  )
}
