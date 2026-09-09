# Lets other packages / sourceCpp pull in the vendored SUNDIALS with
#   // [[Rcpp::depends(sundials)]]
# Rcpp merges env$PKG_CPPFLAGS and env$PKG_LIBS from this plugin into the compile.

inlineCxxPlugin <- function(...) {
  inc <- system.file("include", package = "sundials")
  list(
    env = list(
      PKG_CPPFLAGS = paste0("-I", shQuote(inc)),
      PKG_LIBS = LdFlags()
    )
  )
}
