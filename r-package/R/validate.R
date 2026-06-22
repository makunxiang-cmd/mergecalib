#' Validate cell data and target intervals
#'
#' This function enforces the structural condition required by the package:
#' every province must contain at least one positive-sample original cell, so
#' zero-sample cells can be absorbed into a positive-sample final cluster.
#'
#' @param data Cell-level data frame.
#' @param targets Target interval data frame, or `NULL`.
#' @param spec A `mergecalib_spec` object.
#' @param tolerance Numeric validation tolerance.
#' @return Invisibly returns `TRUE`; otherwise stops with an informative error.
#' @export
validate_merge_data <- function(data, targets = NULL, spec = merge_spec(), tolerance = 1e-8) {
  if (!is.data.frame(data) || !nrow(data)) {
    .mc_stop("mergecalib_error_internal", "`data` must be a data frame with at least one row.")
  }
  req <- .required_columns(spec)
  missing_cols <- setdiff(req, names(data))
  if (length(missing_cols)) {
    .mc_stop("mergecalib_error_internal", "`data` is missing required columns: ", paste(missing_cols, collapse = ", "), ".")
  }
  if (anyNA(data[[spec$id]]) || anyDuplicated(as.character(data[[spec$id]]))) {
    .mc_stop("mergecalib_error_internal", "The cell identifier column `", spec$id, "` must be non-missing and unique.")
  }
  dim_cols <- .all_dimension_columns(spec)
  bad_dim <- dim_cols[vapply(data[dim_cols], anyNA, logical(1))]
  if (length(bad_dim)) {
    .mc_stop("mergecalib_error_internal", "Demographic defining variables must not be missing: ", paste(bad_dim, collapse = ", "), ".")
  }
  dim_key <- do.call(paste, c(lapply(data[dim_cols], as.character), sep = "\r"))
  if (anyDuplicated(dim_key)) {
    dup <- unique(dim_key[duplicated(dim_key) | duplicated(dim_key, fromLast = TRUE)])
    .mc_stop("mergecalib_error_internal", "Each province-by-demographic combination must be unique; found ", length(dup), " duplicated cells.")
  }

  n <- data[[spec$n]]
  w <- data[[spec$weight]]
  if (!.is_integerish(n, tolerance) || any(n < 0)) {
    .mc_stop("mergecalib_error_internal", "The sample-size column `", spec$n, "` must contain non-negative integers.")
  }
  if (!is.numeric(w) || any(!is.finite(w)) || any(w < 0)) {
    .mc_stop("mergecalib_error_internal", "The weight column `", spec$weight, "` must contain finite non-negative numbers.")
  }
  if (any(n > 0 & w <= 0)) {
    bad <- data[[spec$id]][n > 0 & w <= 0]
    .mc_stop("mergecalib_error_internal", "Positive-sample cells must have a positive total weight. Offending cells: ", paste(head(bad, 10), collapse = ", "), ".")
  }

  grade_cols <- unname(spec$grades)
  for (col in grade_cols) {
    x <- data[[col]]
    if (!.is_integerish(x, tolerance) || any(x < 0)) {
      .mc_stop("mergecalib_error_internal", "The grade-count column `", col, "` must contain non-negative integers.")
    }
  }
  grade_sum <- rowSums(data[grade_cols])
  bad_sum <- abs(grade_sum - n) > tolerance
  if (any(bad_sum)) {
    bad <- data[[spec$id]][bad_sum]
    .mc_stop("mergecalib_error_internal", "The grade counts in each row must sum to the sample size. Offending cells: ", paste(head(bad, 10), collapse = ", "), ".")
  }
  if (any(n == 0 & grade_sum != 0)) {
    .mc_stop("mergecalib_error_internal", "Cells with a sample size of 0 must have all grade counts equal to 0.")
  }

  province <- as.character(data[[spec$province]])
  province_n <- tapply(n, province, sum)
  zero_provinces <- names(province_n)[province_n <= 0]
  if (length(zero_provinces)) {
    .mc_stop(
      "mergecalib_error_internal",
      "The following provinces have a total sample size of 0; with cross-province merging disallowed, no positive-sample final cell can be constructed: ",
      paste(zero_provinces, collapse = ", "), "."
    )
  }

  if (!is.null(targets)) {
    .validate_targets(data, targets, spec, tolerance)
  }
  invisible(TRUE)
}

.validate_targets <- function(data, targets, spec, tolerance = 1e-8) {
  if (!is.data.frame(targets) || !nrow(targets)) {
    .mc_stop("mergecalib_error_internal", "`targets` must be a data frame with at least one row.")
  }
  base_req <- c("target_id", "grade", "lower", "upper")
  miss <- setdiff(base_req, names(targets))
  if (length(miss)) {
    .mc_stop("mergecalib_error_internal", "The targets table is missing columns: ", paste(miss, collapse = ", "), ".")
  }
  if (anyNA(targets$target_id) || any(trimws(as.character(targets$target_id)) == "")) {
    .mc_stop("mergecalib_error_internal", "`target_id` must not be empty.")
  }
  key <- paste(targets$target_id, targets$grade, sep = "\r")
  if (anyDuplicated(key)) {
    .mc_stop("mergecalib_error_internal", "Each combination of `target_id` and `grade` may appear only once.")
  }
  if (anyNA(targets$grade) || !all(as.character(targets$grade) %in% names(spec$grades))) {
    .mc_stop("mergecalib_error_internal", "`grade` must be one of: ", paste(names(spec$grades), collapse = ", "), ".")
  }
  if (!is.numeric(targets$lower) || !is.numeric(targets$upper) ||
      any(!is.finite(targets$lower)) || any(!is.finite(targets$upper))) {
    .mc_stop("mergecalib_error_internal", "`lower` and `upper` must be finite numbers.")
  }
  if (any(targets$lower < -tolerance | targets$upper > 1 + tolerance |
          targets$lower > targets$upper + tolerance)) {
    .mc_stop("mergecalib_error_internal", "Target intervals must satisfy 0 <= lower <= upper <= 1.")
  }

  dimensions <- .all_dimension_columns(spec)
  absent <- setdiff(dimensions, names(targets))
  for (col in absent) targets[[col]] <- NA_character_

  ids <- unique(as.character(targets$target_id))
  for (id in ids) {
    z <- targets[as.character(targets$target_id) == id, , drop = FALSE]
    signature <- apply(z[dimensions], 1, function(row) {
      row <- as.character(row)
      row[is.na(row) | trimws(row) %in% .mc_wildcards()] <- "*"
      paste(row, collapse = "\r")
    })
    if (length(unique(signature)) != 1L) {
      .mc_stop("mergecalib_error_internal", "All grades of the same target_id must describe the same target population. Offending target_id: ", id, ".")
    }
    if (length(unique(as.character(z$grade))) == length(spec$grades)) {
      if (sum(z$lower) > 1 + tolerance || sum(z$upper) < 1 - tolerance) {
        .mc_stop("mergecalib_error_internal", "Target `", id, "` has intervals inconsistent with the requirement that the proportions sum to 1.")
      }
    }
  }

  n <- data[[spec$n]]
  for (i in seq_len(nrow(targets))) {
    match <- .match_rows(data, targets[i, , drop = FALSE], dimensions)
    if (!any(match)) {
      .mc_stop("mergecalib_error_internal", "Target row ", i, " (", targets$target_id[i], ") did not match any original cell.")
    }
    if (sum(n[match]) <= 0) {
      .mc_stop(
        "mergecalib_error_internal",
        "Target row ", i, " (", targets$target_id[i],
        ") matches a population with total observed sample size 0; merging does not create observations for that population, so the target is not estimable."
      )
    }
  }
  invisible(TRUE)
}
