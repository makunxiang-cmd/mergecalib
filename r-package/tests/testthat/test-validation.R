test_that("all-zero province is rejected", {
  dat <- example_merge_data()
  dat$n[dat$province == "P1"] <- 0
  dat$A[dat$province == "P1"] <- 0
  dat$B[dat$province == "P1"] <- 0
  dat$C[dat$province == "P1"] <- 0
  dat$D[dat$province == "P1"] <- 0
  expect_error(validate_merge_data(dat), "total sample size of 0")
})

test_that("grade counts must sum to n", {
  dat <- example_merge_data()
  dat$A[1] <- dat$A[1] + 1
  expect_error(validate_merge_data(dat), "must sum to the sample size")
})
