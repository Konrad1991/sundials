# One-off: reference solution of the Robertson problem for
# inst/tinytest/test_link.R. deSolve is only needed here, not by the package.
# Run from the package root:  Rscript development/make_robertson_ref.R

robertson <- function(t, y, parms) {
  list(c(-0.04 * y[1] + 1e4 * y[2] * y[3],
          0.04 * y[1] - 1e4 * y[2] * y[3] - 3e7 * y[2]^2,
          3e7 * y[2]^2))
}

times <- c(0, 0.4 * 10^(0:5))
out <- deSolve::lsode(y = c(1, 0, 0), times = times, func = robertson,
                      parms = NULL, rtol = 1e-12, atol = 1e-20)

ref <- data.frame(t = out[-1, 1], y1 = out[-1, 2], y2 = out[-1, 3], y3 = out[-1, 4])
write.csv(format(ref, digits = 17), "inst/tinytest/robertson_ref.csv",
          row.names = FALSE, quote = FALSE)
print(ref, digits = 10)
