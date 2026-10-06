# Flags for a dependent package's Makevars. Paths are wrapped in literal double
# quotes rather than shQuote() so they work both in $(shell ...) under sh and in
# nmake-style contexts on Windows, where a build prefix may contain spaces.

quoted_path <- function(p) paste0('"', normalizePath(p, winslash = "/", mustWork = TRUE), '"')

ld_flags <- function() {
  libdir <- system.file("lib", .Platform$r_arch, package = "sundials", mustWork = TRUE)
  paste0("-L", quoted_path(libdir), " -lsundials")
}

#' Linker flags for the vendored SUNDIALS static library
#'
#' Prints \code{-L<libdir> -lsundials}. Use from a dependent package that has
#' \code{LinkingTo: sundials} (for the headers) by putting this in its
#' \code{src/Makevars} and \code{src/Makevars.win}:
#'
#' \preformatted{PKG_LIBS = $(shell "$(R_HOME)/bin/Rscript" -e "sundials::LdFlags()")}
#'
#' @return The flag string, invisibly; also printed to stdout.
#' @export
LdFlags <- function() {
  flags <- ld_flags()
  cat(flags)
  invisible(flags)
}

#' Include flag for the vendored SUNDIALS headers
#'
#' \code{LinkingTo: sundials} already adds the headers to the compile path, so
#' this is only needed when building outside the \code{LinkingTo} mechanism
#' (e.g. \code{Rcpp::sourceCpp}).
#'
#' @return The flag string, invisibly; also printed to stdout.
#' @export
CFlags <- function() {
  inc <- system.file("include", package = "sundials", mustWork = TRUE)
  flags <- paste0("-I", quoted_path(inc))
  cat(flags)
  invisible(flags)
}
