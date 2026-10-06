# sundials 7.9.0-1

* First version. Vendors SUNDIALS 7.9.0 (CVODE, CVODES, ARKODE, IDA, IDAS,
  KINSOL; serial vector; dense, band and iterative linear solvers) as a static
  library. No Fortran, MPI, GPU or external-library modules. Double precision,
  64-bit indices.
* One source patch: deprecation attributes are disabled for the package's own
  build of SUNDIALS (dependents still see them).
