test_that("candidate set forbids zero-sample final clusters", {
  dat <- example_merge_data()
  spec <- merge_spec(level_orders = list(
    age = c("18-39", "40+"), education = c("low", "high")
  ))
  cand <- generate_candidate_clusters(
    dat, spec, max_cluster_size = 3, max_neighbors = 5
  )
  expect_true(all(cand$n_total > 0))

  zero_rows <- which(dat$n == 0)
  for (z in zero_rows) {
    covered <- vapply(cand$members, function(m) z %in% m, logical(1))
    expect_true(any(covered))
    expect_true(all(cand$n_total[covered] > 0))
  }
})
