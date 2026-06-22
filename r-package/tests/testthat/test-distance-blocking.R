test_that("blocked candidate generation preserves deterministic small fixture", {
  spec <- merge_spec(level_orders = list(
    age = c("18-39", "40+"),
    education = c("low", "high")
  ))
  dat <- example_merge_data()[1:8, , drop = FALSE]

  cand <- generate_candidate_clusters(
    dat, spec,
    max_cluster_size = 3,
    max_neighbors = 3
  )

  expect_equal(
    cand$cluster_key,
    c(
      "1", "1:2", "1:2:3", "1:2:4", "1:2:5", "1:3", "1:3:4",
      "1:3:5", "1:5", "2", "2:3", "2:3:4", "2:4", "2:4:8",
      "2:5:6", "2:6", "2:6:8", "3:4", "3:4:8", "3:5:7",
      "3:7", "3:7:8", "4", "4:8", "5", "5:6", "5:6:7",
      "5:6:8", "5:7", "5:7:8", "5:8", "6", "6:7:8", "6:8",
      "7", "7:8", "8"
    )
  )
  expect_equal(
    cand$n_total,
    c(
      12, 31, 31, 47, 37, 12, 28, 18, 18, 19, 19, 35, 35, 45,
      38, 32, 42, 16, 26, 26, 20, 30, 16, 26, 6, 19, 39, 29,
      26, 36, 16, 13, 43, 23, 20, 30, 10
    )
  )
  expect_equal(
    cand$demo_distance,
    c(
      0, 12, 14, 28, 30, 1, 25, 13, 12, 0, 2, 18, 16, 46,
      44, 26, 56, 1, 21, 8, 2, 12, 0, 20, 0, 6, 32, 16,
      6, 16, 12, 0, 36, 10, 0, 10, 0
    )
  )
  expect_true(all(cand$n_total > 0))
})

test_that("distance block helper only returns province-sized matrices", {
  spec <- merge_spec(level_orders = list(
    age = c("18-39", "40+"),
    education = c("low", "high")
  ))
  dat <- example_merge_data()
  p1 <- dat[dat$province == "P1", , drop = FALSE]

  dist <- .distance_matrix_block(p1, spec)

  expect_equal(dim(dist), c(nrow(p1), nrow(p1)))
  expect_true(all(diag(dist) == 0))
})

test_that("implicit ordered levels preserve national spacing inside province blocks", {
  dat <- data.frame(
    province = c("P1", "P1", "P1", "P2", "P2"),
    cell_id = paste0("C", 1:5),
    n = c(5L, 6L, 7L, 8L, 11L),
    weight = c(5, 6, 7, 8, 11),
    A = c(5L, 6L, 7L, 8L, 11L),
    B = 0L,
    C = 0L,
    D = 0L,
    sex = "F",
    urban = "U",
    age = c("a", "b", "c", "a", "c"),
    education = "same",
    stringsAsFactors = FALSE
  )
  spec <- merge_spec(ordered_groups = "age")

  cand <- generate_candidate_clusters(
    dat, spec,
    max_cluster_size = 2,
    max_neighbors = 1,
    max_distance = 2
  )
  p2_pair <- cand[cand$cluster_key == "4:5", , drop = FALSE]

  expect_equal(nrow(p2_pair), 1L)
  expect_equal(p2_pair$demo_distance, 16)

  tight <- generate_candidate_clusters(
    dat, spec,
    max_cluster_size = 2,
    max_neighbors = 1,
    max_distance = 1
  )
  expect_false("4:5" %in% tight$cluster_key)
})

test_that("distance lookup maps later global rows and rejects out-of-block rows", {
  dist_mat <- matrix(c(0, 7, 7, 0), nrow = 2)
  lookup <- .dist_lookup_block(dist_mat, c(`4` = 1L, `8` = 2L))

  expect_equal(lookup(8, 4), 7)
  expect_equal(lookup(c(4, 8), 4), c(0, 7))
  expect_error(
    lookup(4, 5),
    class = "mergecalib_error_internal"
  )
})
