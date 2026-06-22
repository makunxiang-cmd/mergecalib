test_that("weight-ratio warnings fire when threshold is low", {
  skip_if_not_installed("highs")
  old_warn <- getOption("mergecalib.warn")
  old_thresholds <- getOption("mergecalib.warning_thresholds")
  on.exit({
    options(mergecalib.warn = old_warn)
    options(mergecalib.warning_thresholds = old_thresholds)
  }, add = TRUE)

  options(
    mergecalib.warn = TRUE,
    mergecalib.warning_thresholds = list(max_weight_ratio = 1)
  )

  dat <- example_merge_data()
  spec <- merge_spec(level_orders = list(
    age = c("18-39", "40+"),
    education = c("low", "high")
  ))
  targets <- example_merge_targets(dat, spec, half_width = 0.03)

  expect_warning(
    fit_merge_calibration(
      dat, targets, spec,
      solver_control = list(time_limit = 60)
    ),
    class = "mergecalib_warning_weight_distortion"
  )
})

test_that("mergecalib.warn disables post-fit warnings", {
  skip_if_not_installed("highs")
  old_warn <- getOption("mergecalib.warn")
  old_thresholds <- getOption("mergecalib.warning_thresholds")
  on.exit({
    options(mergecalib.warn = old_warn)
    options(mergecalib.warning_thresholds = old_thresholds)
  }, add = TRUE)

  options(
    mergecalib.warn = FALSE,
    mergecalib.warning_thresholds = list(max_weight_ratio = 1)
  )

  dat <- example_merge_data()
  spec <- merge_spec(level_orders = list(
    age = c("18-39", "40+"),
    education = c("low", "high")
  ))
  targets <- example_merge_targets(dat, spec, half_width = 0.03)

  expect_warning(
    fit_merge_calibration(
      dat, targets, spec,
      solver_control = list(time_limit = 60)
    ),
    NA
  )
})

test_that("near-binding warnings can be triggered with a wide margin", {
  skip_if_not_installed("highs")
  old_warn <- getOption("mergecalib.warn")
  old_thresholds <- getOption("mergecalib.warning_thresholds")
  on.exit({
    options(mergecalib.warn = old_warn)
    options(mergecalib.warning_thresholds = old_thresholds)
  }, add = TRUE)

  options(
    mergecalib.warn = TRUE,
    mergecalib.warning_thresholds = list(near_binding_margin = 1)
  )

  dat <- example_merge_data()
  spec <- merge_spec(level_orders = list(
    age = c("18-39", "40+"),
    education = c("low", "high")
  ))
  targets <- example_merge_targets(dat, spec, half_width = 0.03)

  expect_warning(
    fit_merge_calibration(
      dat, targets, spec,
      solver_control = list(time_limit = 60)
    ),
    class = "mergecalib_warning_near_binding"
  )
})
