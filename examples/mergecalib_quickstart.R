# mergecalib quick start
# 1) Install dependency and package:
# install.packages("highs")
# install.packages("mergecalib_0.1.0.tar.gz", repos = NULL, type = "source")

library(mergecalib)

spec <- merge_spec(
  level_orders = list(
    age = c("18-39", "40+"),
    education = c("low", "high")
  )
)

dat <- example_merge_data()
targets <- example_merge_targets(dat, spec)

fit <- fit_merge_calibration(
  data = dat,
  targets = targets,
  spec = spec,
  solver_control = list(time_limit = 300)
)

print(fit)
print(summary(fit))
stopifnot(audit_merge_fit(fit)$valid)
stopifnot(all(final_cells(fit)$final_n > 0))

export_merge_results(fit, "mergecalib_results", overwrite = TRUE)
