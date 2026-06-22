test_that("disclaimer text is available", {
  txt <- mergecalib_disclaimer(print = FALSE)
  expect_type(txt, "character")
  expect_match(txt, "DISCLAIMER")
})

test_that("agreement is recorded in session options", {
  old <- getOption("mergecalib.agreed")
  on.exit(options(mergecalib.agreed = old), add = TRUE)
  mergecalib_agree(TRUE)
  expect_true(isTRUE(getOption("mergecalib.agreed")))
  mergecalib_agree(FALSE)
  expect_false(isTRUE(getOption("mergecalib.agreed")))
})

test_that("consent gate never blocks non-interactive use", {
  old <- getOption("mergecalib.agreed")
  on.exit(options(mergecalib.agreed = old), add = TRUE)
  options(mergecalib.agreed = NULL)
  expect_true(mergecalib:::.mc_require_consent())
})
