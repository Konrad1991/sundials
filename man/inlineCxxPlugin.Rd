\name{inlineCxxPlugin}
\alias{inlineCxxPlugin}
\title{Rcpp plugin for the vendored SUNDIALS library}
\usage{
inlineCxxPlugin(...)
}
\arguments{
\item{...}{Ignored; present for compatibility with the plugin interface.}
}
\value{
A list with element \code{env} holding \code{PKG_CPPFLAGS} (the include
flag) and \code{PKG_LIBS} (the linker flags from \code{\link{LdFlags}}).
}
\description{
Lets \code{Rcpp::sourceCpp} and \code{Rcpp::cppFunction} compile against the
SUNDIALS headers and static library shipped in this package. Not called
directly; it is picked up by the attribute
\preformatted{// [[Rcpp::depends(sundials)]]}
}
\seealso{\code{\link{LdFlags}}, \code{\link{CFlags}}}
\examples{
str(inlineCxxPlugin())
}
