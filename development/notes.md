# sundials package — dev notes

## What this package is

Vendored pure-C SUNDIALS built into `inst/lib/libsundials.a` for other packages
to link via `LinkingTo: sundials` + `sundials::LdFlags()`.

## Re-vendoring a new SUNDIALS release

```
tools/vendor.sh 7.9.0        # or the desired version
```

Needs `cmake`, `curl`, `python3`, `tar`. It:

1. downloads the release tarball from the LLNL GitHub releases
2. runs `cmake` configure-only to generate `sundials_config.h` and
   `sundials_export.h` (the two headers CMake owns), pinned to:
   double precision, `SUNDIALS_INDEX_SIZE=64`, no MPI/GPU/Fortran/TPL,
   profiling off, logging level 0, all six solver packages on
3. copies the compiled subset (read back from `compile_commands.json`) into
   `src/sundials/`, plus every private header from those dirs and from
   `src/sundials/**` (incl. header-only `stl/`)
4. copies the public headers into `inst/include/` (with `sundials/priv/`)
5. writes `src/Makevars` + `src/Makevars.win` from `tools/Makevars.in`, inlining
   the object list (a separate `*.mk` in `src/` triggers a check WARNING)

## Source patches to SUNDIALS

One, applied by `vendor.sh`: `sundials_config.h` gets a guard that empties
`SUNDIALS_DEPRECATED_MSG(msg)` when `SUNDIALS_R_NO_DEPRECATION_WARNINGS` is
defined (only our `Makevars` does). SUNDIALS calls its own deprecated
work-space API internally, which R CMD check flags as significant warnings.

Otherwise none. SUNDIALS 7.9.0 already ships the C hygiene that CRAN forced by hand on
the 6.5.0 vendoring in `paropt` (checked by diffing paropt's tree vs pristine
6.5.0):

| paropt 6.5.0 patch | status in 7.9.0 |
| --- | --- |
| `f()` -> `f(void)` in `sundials_memory.c`, `sundials_profiler.c`, `sundials_memory.h` | fixed upstream (`sunTimerStructNew(void)`; `SUNMemoryNewEmpty` now takes an arg) |
| hashmap FNV consts `unsigned long` -> `unsigned long long` (Windows LLP64 overflow) | fixed upstream (`uint64_t`) |
| `#include "sundials_context_impl.h"` -> `"sundials/..."` | restructured upstream to `<sundials/priv/sundials_context_impl.h>` |

If a future release regresses, add patches under `tools/patches/` and apply them
at the end of `vendor.sh`.

## Build verification

- all 131 TUs compile clean with R's `CFLAGS` + `-Wall -Wextra -Wstrict-prototypes`;
  `-Wdeprecated-declarations` silenced via the patch above
- `tools/check_linkage.sh` builds the archive the same way the package does and
  links + runs a CVODE dense example against it
- upstream `ctest` (same cmake flags, examples enabled) is the full check
