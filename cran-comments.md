## Submission

This is a new submission.

The package vendors the pure-C part of the SUNDIALS 7.9.0 solver suite
(CVODE, CVODES, ARKODE, IDA, IDAS, KINSOL) and builds it into a static
library so that other packages can link it via `LinkingTo: sundials` and
`sundials::LdFlags()` in their `Makevars`. The approach follows other
library-providing packages: one maintained copy of SUNDIALS instead of a
separate copy inside every package that needs it.

## Test environments

* local: Ubuntu 24.04, R 4.6.1
* R-hub: linux, macos, macos-arm64, windows (all R-devel), ubuntu-release,
  ubuntu-next, gcc15, clang20, lto, nosuggests, gcc-asan, clang-asan,
  clang-ubsan, valgrind

## R CMD check results

0 errors | 0 warnings | 1 note

* checking CRAN incoming feasibility ... NOTE
  New submission

## Notes for the reviewer

* **Installed size (~12 Mb).** Almost all of it is `lib/libsundials.a`,
  the static library that dependent packages link against. This is the
  purpose of the package.

* **Shared object without routines.** `src/init.c` only registers an empty
  routine table. The package's R functions return the compiler and linker
  flags; the compiled code is consumed by other packages through the static
  library.

* **Building into `inst/lib`.** `src/Makevars` writes the archive to
  `../inst/lib$(R_ARCH)`, which R then installs as `lib/`. `R_ARCH` keeps
  sub-architectures separate.

* **Copyright and authorship.** The SUNDIALS copyright holders are listed in
  `Authors@R` with role `cph`. The individual SUNDIALS authors are listed in
  `inst/AUTHORS`; full notices are in `inst/COPYRIGHTS`,
  `inst/SUNDIALS-LICENSE` and `inst/SUNDIALS-NOTICE`.

* **Modification of the upstream sources.** There is one modification:
  `sundials_config.h` gets a guarded macro that removes the `deprecated`
  attribute while this package compiles SUNDIALS, because SUNDIALS calls its
  own deprecated API internally. Packages that use the headers still see the
  deprecation warnings. The modification is applied reproducibly by
  `tools/vendor.sh` and documented in `NEWS.md`.

* **CVODE and IDA.** They are provided by CVODES and IDAS (same API,
  supersets); compiling both into one static library would define the same
  symbols twice.
