#' Generate reproducible example cell data
#'
#' The example contains two zero-sample cells with positive total weight. They
#' cannot remain as final cells and must be absorbed into positive-sample cells.
#'
#' @return A cell-level data frame.
#' @export
example_merge_data <- function() {
  x <- expand.grid(
    province = c("P1", "P2"),
    sex = c("M", "F"),
    urban = c("urban", "rural"),
    age = c("18-39", "40+"),
    education = c("low", "high"),
    KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )
  x <- x[.lex_order(x$province, x$sex, x$urban, x$age, x$education), , drop = FALSE]
  rownames(x) <- NULL
  x$cell_id <- sprintf("C%03d", seq_len(nrow(x)))
  base_n <- 5 + ((seq_len(nrow(x)) * 7L) %% 17L)
  x$n <- as.integer(base_n)
  x$n[c(3, 19)] <- 0L

  score <-
    0.03 * (x$province == "P2") +
    0.04 * (x$sex == "F") +
    0.05 * (x$urban == "urban") +
    0.06 * (x$age == "40+") +
    0.05 * (x$education == "high")
  pA <- pmin(0.42, 0.20 + score)
  pB <- 0.30 - 0.20 * score
  pC <- 0.28 - 0.10 * score
  pD <- 1 - pA - pB - pC
  probs <- cbind(A = pA, B = pB, C = pC, D = pD)

  counts <- matrix(0L, nrow(x), 4L, dimnames = list(NULL, c("A", "B", "C", "D")))
  for (i in seq_len(nrow(x))) {
    if (x$n[i] > 0) {
      raw <- x$n[i] * probs[i, ]
      z <- floor(raw)
      remainder <- x$n[i] - sum(z)
      if (remainder > 0) {
        ord <- order(raw - z, decreasing = TRUE, method = "radix")
        z[ord[seq_len(remainder)]] <- z[ord[seq_len(remainder)]] + 1L
      }
      counts[i, ] <- as.integer(z)
    }
  }
  x$A <- counts[, "A"]
  x$B <- counts[, "B"]
  x$C <- counts[, "C"]
  x$D <- counts[, "D"]
  unit <- 0.75 + ((seq_len(nrow(x)) * 11L) %% 19L) / 20
  x$weight <- x$n * unit
  x$weight[c(3, 19)] <- c(7.5, 5.0)
  x[c("cell_id", "province", "sex", "urban", "age", "education",
      "n", "weight", "A", "B", "C", "D")]
}

.reference_full_province_contributions <- function(data, spec) {
  province <- as.character(data[[spec$province]])
  u <- numeric(nrow(data))
  for (p in unique(province)) {
    idx <- which(province == p)
    u[idx] <- sum(data[[spec$weight]][idx]) / sum(data[[spec$n]][idx])
  }
  list(unit = u, denominator = u * data[[spec$n]])
}

#' Generate feasible example interval targets
#'
#' Targets are centered on a deterministic full-province reference merge, so
#' the widest default candidate level is guaranteed to contain a strict
#' feasible solution.
#'
#' @param data Cell data, normally from `example_merge_data()`.
#' @param spec A `mergecalib_spec`.
#' @param half_width Half-width of each target interval.
#' @return A target data frame.
#' @export
example_merge_targets <- function(
  data = example_merge_data(),
  spec = merge_spec(
    level_orders = list(age = c("18-39", "40+"), education = c("low", "high"))
  ),
  half_width = 0.02
) {
  validate_merge_data(data, spec = spec)
  ref <- .reference_full_province_contributions(data, spec)
  grade_names <- names(spec$grades)
  dims <- .all_dimension_columns(spec)
  rows <- list()
  k <- 0L

  add_target <- function(target_id, target_name, scope, fixed) {
    use <- rep(TRUE, nrow(data))
    for (nm in names(fixed)) use <- use & as.character(data[[nm]]) == as.character(fixed[[nm]])
    denom <- sum(ref$denominator[use])
    ans <- vector("list", length(grade_names))
    for (gi in seq_along(grade_names)) {
      g <- grade_names[gi]
      grade_col <- unname(spec$grades[[g]])
      value <- sum(ref$unit[use] * data[[grade_col]][use]) / denom
      row <- as.list(stats::setNames(rep(NA_character_, length(dims)), dims))
      for (nm in names(fixed)) row[[nm]] <- as.character(fixed[[nm]])
      row$target_id <- target_id
      row$target_name <- target_name
      row$scope <- scope
      row$grade <- g
      row$lower <- max(0, value - half_width)
      row$upper <- min(1, value + half_width)
      ans[[gi]] <- row
    }
    ans
  }

  for (p in sort(unique(as.character(data[[spec$province]])), method = "radix")) {
    z <- add_target(
      paste0("province_", .safe_name(p)),
      paste0("Province: ", p),
      "province",
      stats::setNames(list(p), spec$province)
    )
    for (row in z) {
      k <- k + 1L
      rows[[k]] <- row
    }
  }

  for (gname in names(spec$groups)) {
    col <- spec$groups[[gname]]
    values <- sort(unique(as.character(data[[col]])), method = "radix")
    for (value in values) {
      z <- add_target(
        paste0("national_", gname, "_", .safe_name(value)),
        paste0("National ", gname, "=", value),
        "national_margin",
        stats::setNames(list(value), col)
      )
      for (row in z) {
        k <- k + 1L
        rows[[k]] <- row
      }
    }
  }

  out <- .list_rbind(rows)
  first <- c("target_id", "target_name", "scope", "grade", "lower", "upper")
  out[c(first, dims)]
}
