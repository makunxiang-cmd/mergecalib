test_that("all-zero province is rejected with structural class", {
  dat <- example_merge_data()
  dat$n[dat$province == "P1"] <- 0
  dat$A[dat$province == "P1"] <- 0
  dat$B[dat$province == "P1"] <- 0
  dat$C[dat$province == "P1"] <- 0
  dat$D[dat$province == "P1"] <- 0

  expect_error(
    validate_merge_data(dat),
    class = "mergecalib_error_structural"
  )
})

test_that("grade counts must sum to n with input class", {
  dat <- example_merge_data()
  dat$A[1] <- dat$A[1] + 1

  expect_error(
    validate_merge_data(dat),
    class = "mergecalib_error_input"
  )
})

test_that("unestimable targets are rejected with not-estimable class", {
  dat <- example_merge_data()
  dat$n[dat$sex == "F"] <- 0
  dat$A[dat$sex == "F"] <- 0
  dat$B[dat$sex == "F"] <- 0
  dat$C[dat$sex == "F"] <- 0
  dat$D[dat$sex == "F"] <- 0
  targets <- data.frame(
    target_id = "female",
    grade = "A",
    lower = 0.1,
    upper = 0.9,
    province = NA,
    sex = "F",
    urban = NA,
    age = NA,
    education = NA,
    stringsAsFactors = FALSE
  )

  expect_error(
    validate_merge_data(dat, targets),
    class = "mergecalib_error_not_estimable"
  )
})
