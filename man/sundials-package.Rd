\name{sundials-package}
\alias{sundials-package}
\alias{sundials}
\docType{package}
\title{Vendored SUNDIALS solver suite for linking by other packages}
\description{
Bundles the pure-C part of the SUNDIALS suite (CVODE, CVODES, ARKODE, IDA, IDAS,
KINSOL, with the serial N_Vector and the dense, band and iterative linear
solvers) and builds it into a static library, \file{libsundials.a}, under the
package's \file{lib} directory. Other packages link it with
\code{LinkingTo: sundials} (for the headers) and
\code{\link{LdFlags}()} in their \file{Makevars}.

No Fortran, MPI, GPU or external third-party-library modules are included. The
build is double precision with 64-bit indices.
}
\references{
Hindmarsh, A. C., Brown, P. N., Grant, K. E., Lee, S. L., Serban, R.,
Shumaker, D. E., Woodward, C. S. (2005). SUNDIALS: Suite of Nonlinear and
Differential/Algebraic Equation Solvers. \emph{ACM Transactions on
Mathematical Software}, 31(3), 363-396. \doi{10.1145/1089014.1089020}

\url{https://computing.llnl.gov/projects/sundials}
}
\seealso{\code{\link{LdFlags}}}
\keyword{package}
