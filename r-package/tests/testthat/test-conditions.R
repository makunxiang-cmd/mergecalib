test_that("mergecalib errors carry specific and base classes", {
  err <- tryCatch(
    .mc_stop("mergecalib_error_input", "`data` must be a data frame."),
    error = identity
  )

  expect_s3_class(err, "mergecalib_error_input")
  expect_s3_class(err, "mergecalib_error")
  expect_s3_class(err, "error")
  expect_match(conditionMessage(err), "`data` must be a data frame.", fixed = TRUE)
})

test_that("mergecalib warnings carry specific and base classes", {
  warn <- NULL
  withCallingHandlers(
    .mc_warn("mergecalib_warning_relaxation", "Large relaxation was required."),
    warning = function(w) {
      warn <<- w
      invokeRestart("muffleWarning")
    }
  )

  expect_s3_class(warn, "mergecalib_warning_relaxation")
  expect_s3_class(warn, "mergecalib_warning")
  expect_s3_class(warn, "warning")
  expect_match(conditionMessage(warn), "Large relaxation was required.", fixed = TRUE)
})

test_that("mergecalib warnings obey the global warning switch", {
  old <- getOption("mergecalib.warn")
  on.exit(options(mergecalib.warn = old), add = TRUE)
  options(mergecalib.warn = FALSE)

  expect_warning(
    .mc_warn("mergecalib_warning_relaxation", "This warning is disabled."),
    NA
  )
})

test_that("warning thresholds are merged with defaults", {
  old <- getOption("mergecalib.warning_thresholds")
  on.exit(options(mergecalib.warning_thresholds = old), add = TRUE)
  options(mergecalib.warning_thresholds = list(max_weight_ratio = 2))

  thresholds <- .mc_warning_thresholds()
  expect_equal(thresholds$max_weight_ratio, 2)
  expect_equal(thresholds$relaxation_delta, 0.02)
  expect_equal(thresholds$near_binding_margin, 0.005)
})

test_that("merge_spec validation failures use spec class", {
  expect_error(
    merge_spec(grades = character()),
    class = "mergecalib_error_spec"
  )
})

test_that("result accessors reject non-fit objects with input class", {
  expect_error(
    audit_merge_fit(list()),
    class = "mergecalib_error_input"
  )
})
