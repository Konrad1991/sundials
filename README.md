# sundials

Vendored [SUNDIALS](https://computing.llnl.gov/projects/sundials) suite, built
into a static library for other R packages to link against.

Contains the pure-C part of CVODE, CVODES, ARKODE, IDA, IDAS and KINSOL with the
serial vector and the dense, band and iterative (SPGMR/SPFGMR/SPBCGS/SPTFQMR/PCG)
linear solvers. No Fortran, MPI, GPU or external-library modules. Double
precision, 64-bit indices (`sunindextype = int64_t`).

## Use from another package

`DESCRIPTION`:

```
LinkingTo: sundials
```

`src/Makevars` and `src/Makevars.win`:

```make
PKG_LIBS = $(shell "$(R_HOME)/bin/Rscript" -e "sundials::LdFlags()")
```

`LinkingTo` puts the SUNDIALS headers on the compile path; `LdFlags()` adds
`-L<libdir> -lsundials`. Then include and call SUNDIALS as usual:

```c
#include <cvode/cvode.h>
#include <nvector/nvector_serial.h>
#include <sunlinsol/sunlinsol_dense.h>
```

## Updating the vendored SUNDIALS

```
tools/vendor.sh 7.9.0
```

Downloads the release, regenerates the config headers with `cmake`, refreshes
`src/sundials/**`, `inst/include/**` and `src/sundials_srcs.mk`. See
`development/notes.md`.

## Licence

The vendored SUNDIALS source is BSD 3-Clause, Copyright Lawrence Livermore
National Security, Southern Methodist University, University of Maryland
Baltimore County and the SUNDIALS contributors. See `LICENSE`, `inst/COPYRIGHTS`,
`inst/AUTHORS`. The package's own glue code is offered under the same terms.
