\name{LdFlags}
\alias{LdFlags}
\alias{CFlags}
\title{Build flags for the vendored SUNDIALS library}
\usage{
LdFlags()

CFlags()
}
\value{
The flag string, returned invisibly and also printed to \code{stdout} so it can
be captured by \code{$(shell ...)} in a Makevars file.
}
\description{
\code{LdFlags} prints \code{-L<libdir> -lsundials} for linking against the
static SUNDIALS library shipped in this package. \code{CFlags} prints
\code{-I<includedir>} for its headers; this is only needed outside the
\code{LinkingTo} mechanism.
}
\details{
In the dependent package's \code{DESCRIPTION}:
\preformatted{LinkingTo: sundials}

In its \code{src/Makevars} and \code{src/Makevars.win}:
\preformatted{PKG_LIBS = $(shell "$(R_HOME)/bin/Rscript" -e "sundials::LdFlags()")}

The vendored build is double precision with 64-bit indices
(\code{sunindextype = int64_t}) and contains no Fortran, MPI, GPU or
external-library modules.
}
\examples{
LdFlags()
CFlags()
}
