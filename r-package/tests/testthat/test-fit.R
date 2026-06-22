test_that("fitted solution has no zero-sample final cluster", {
  skip_if_not_installed("highs")
  dat <- example_merge_data()
  spec <- merge_spec(level_orders = list(
    age = c("18-39", "40+"), education = c("low", "high")
  ))
  targets <- example_merge_targets(dat, spec, half_width = 0.03)
  fit <- fit_merge_calibration(
    dat, targets, spec,
    solver_control = list(time_limit = 60)
  )
  expect_true(all(final_cells(fit)$final_n > 0))
  expect_equal(audit_merge_fit(fit)$zero_sample_final_cells, 0)
  expect_true(audit_merge_fit(fit)$valid)
})
