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

test_that("invalid max_delta uses input class", {
  skip_if_not_installed("highs")
  dat <- example_merge_data()
  spec <- merge_spec(level_orders = list(
    age = c("18-39", "40+"),
    education = c("low", "high")
  ))
  targets <- example_merge_targets(dat, spec)

  expect_error(
    fit_merge_calibration(dat, targets, spec, max_delta = 2),
    class = "mergecalib_error_input"
  )
})

test_that("disabled relaxation uses infeasible class when strict targets fail", {
  skip_if_not_installed("highs")
  dat <- example_merge_data()
  spec <- merge_spec(level_orders = list(
    age = c("18-39", "40+"),
    education = c("low", "high")
  ))
  targets <- example_merge_targets(dat, spec, half_width = 0)

  expect_error(
    fit_merge_calibration(
      dat, targets, spec,
      candidate_levels = default_candidate_levels()[1],
      relax_targets = FALSE,
      solver_control = list(time_limit = 60)
    ),
    class = "mergecalib_error_infeasible"
  )
})

test_that("invalid solver_control uses input class", {
  skip_if_not_installed("highs")
  dat <- example_merge_data()
  spec <- merge_spec(level_orders = list(
    age = c("18-39", "40+"),
    education = c("low", "high")
  ))
  targets <- example_merge_targets(dat, spec, half_width = 0)
  bad_controls <- list(
    non_list = 1,
    unnamed = list(60),
    unknown_option = list(not_a_highs_option = 1),
    invalid_threads = list(threads = 0)
  )

  for (solver_control in bad_controls) {
    expect_error(
      fit_merge_calibration(
        dat, targets, spec,
        candidate_levels = default_candidate_levels()[1],
        relax_targets = FALSE,
        solver_control = solver_control
      ),
      class = "mergecalib_error_input"
    )
  }
})

test_that("malformed objective_order uses input class", {
  skip_if_not_installed("highs")
  dat <- example_merge_data()
  spec <- merge_spec(level_orders = list(
    age = c("18-39", "40+"),
    education = c("low", "high")
  ))
  targets <- example_merge_targets(dat, spec, half_width = 0.03)
  bad_orders <- list(
    non_character = list(c("moved_n", "bad")),
    empty = character(),
    missing = c("moved_n", NA_character_),
    duplicate = c("moved_n", "moved_n")
  )

  for (objective_order in bad_orders) {
    expect_error(
      fit_merge_calibration(
        dat, targets, spec,
        objective_order = objective_order,
        solver_control = list(time_limit = 60)
      ),
      class = "mergecalib_error_input"
    )
  }
})
