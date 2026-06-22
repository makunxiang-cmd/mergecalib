.build_cell_contributions <- function(fit, cluster_map) {
  data <- fit$data
  spec <- fit$spec
  n <- data[[spec$n]]
  w <- data[[spec$weight]]
  grade_names <- names(spec$grades)
  out <- data
  out$initial_unit_weight <- ifelse(n > 0, w / n, NA_real_)
  out$final_cluster_id <- cluster_map$final_cluster_id
  out$final_unit_weight <- cluster_map$final_unit_weight
  out$initial_denominator <- ifelse(n > 0, w, 0)
  out$final_denominator <- out$final_unit_weight * n
  for (g in grade_names) {
    col <- unname(spec$grades[[g]])
    out[[paste0("initial_num_", g)]] <- ifelse(
      n > 0, out$initial_unit_weight * data[[col]], 0
    )
    out[[paste0("final_num_", g)]] <- out$final_unit_weight * data[[col]]
  }
  out
}

.build_fit_outputs <- function(fit) {
  data <- fit$data
  spec <- fit$spec
  candidates <- fit$candidates
  selected <- fit$selected_candidate_indices
  chosen <- candidates[selected, , drop = FALSE]
  ord <- .lex_order(chosen$province, chosen$anchor_id, chosen$cluster_key)
  chosen <- chosen[ord, , drop = FALSE]
  chosen$final_cluster_id <- sprintf("F%06d", seq_len(nrow(chosen)))

  grade_names <- names(spec$grades)
  final_rows <- vector("list", nrow(chosen))
  map_rows <- vector("list", nrow(chosen))
  step_rows <- list()
  step_counter <- 0L

  for (j in seq_len(nrow(chosen))) {
    members <- chosen$members[[j]]
    anchor <- chosen$anchor_index[j]
    cluster_id <- chosen$final_cluster_id[j]
    source <- setdiff(members, anchor)
    if (length(source)) {
      source <- source[.lex_order(
        data[[spec$n]][source],
        as.character(data[[spec$id]][source])
      )]
    }
    merge_order <- rep(0L, length(members))
    names(merge_order) <- as.character(members)
    if (length(source)) merge_order[as.character(source)] <- seq_along(source)

    mapping <- data.frame(
      .mc_index = members,
      final_cluster_id = cluster_id,
      selected_candidate_id = chosen$cluster_id[j],
      anchor_id = chosen$anchor_id[j],
      merge_order = as.integer(merge_order[as.character(members)]),
      final_unit_weight = chosen$unit_weight[j],
      stringsAsFactors = FALSE
    )
    map_rows[[j]] <- mapping

    row <- data.frame(
      final_cluster_id = cluster_id,
      selected_candidate_id = chosen$cluster_id[j],
      province = chosen$province[j],
      anchor_id = chosen$anchor_id[j],
      final_n = chosen$n_total[j],
      final_weight = chosen$weight_total[j],
      final_unit_weight = chosen$unit_weight[j],
      original_cell_count = chosen$cluster_size[j],
      merged_cell_count = chosen$merge_count[j],
      moved_n = chosen$moved_n[j],
      demo_distance = chosen$demo_distance[j],
      heterogeneity = chosen$heterogeneity[j],
      weight_distortion = chosen$weight_distortion[j],
      max_weight_ratio = chosen$max_weight_ratio[j],
      stringsAsFactors = FALSE
    )
    totals <- chosen$grade_totals[[j]]
    for (k in seq_along(grade_names)) {
      g <- grade_names[k]
      underlying <- unname(spec$grades[[g]])
      pos <- match(underlying, names(totals))
      value <- if (!is.na(pos)) unname(totals[pos]) else unname(totals[k])
      row[[paste0("count_", g)]] <- value
    }
    final_rows[[j]] <- row

    current_n <- data[[spec$n]][anchor]
    current_w <- data[[spec$weight]][anchor]
    if (length(source)) {
      for (s in seq_along(source)) {
        src <- source[s]
        before_n <- current_n
        before_w <- current_w
        current_n <- current_n + data[[spec$n]][src]
        current_w <- current_w + data[[spec$weight]][src]
        step_counter <- step_counter + 1L
        step_rows[[step_counter]] <- data.frame(
          step = step_counter,
          province = chosen$province[j],
          final_cluster_id = cluster_id,
          source_cell_id = as.character(data[[spec$id]][src]),
          target_anchor_id = chosen$anchor_id[j],
          source_n = data[[spec$n]][src],
          source_weight = data[[spec$weight]][src],
          target_n_before = before_n,
          target_weight_before = before_w,
          merged_n = current_n,
          merged_weight = current_w,
          merged_unit_weight = current_w / current_n,
          stringsAsFactors = FALSE
        )
      }
    }
  }

  final_df <- do.call(rbind, final_rows)
  map_df <- do.call(rbind, map_rows)
  rownames(final_df) <- NULL
  rownames(map_df) <- NULL
  map_df <- map_df[match(seq_len(nrow(data)), map_df$.mc_index), , drop = FALSE]

  cell_map_df <- data
  cell_map_df$final_cluster_id <- map_df$final_cluster_id
  cell_map_df$selected_candidate_id <- map_df$selected_candidate_id
  cell_map_df$anchor_id <- map_df$anchor_id
  cell_map_df$merge_order <- map_df$merge_order
  cell_map_df$final_unit_weight <- map_df$final_unit_weight
  cell_map_df <- cell_map_df[.lex_order(cell_map_df$.mergecalib_original_row__), , drop = FALSE]
  cell_map_df$.mergecalib_original_row__ <- NULL
  rownames(cell_map_df) <- NULL

  cluster_map_internal <- map_df
  contrib <- .build_cell_contributions(fit, cluster_map_internal)
  merge_steps_df <- if (length(step_rows)) do.call(rbind, step_rows) else {
    data.frame(
      step = integer(), province = character(), final_cluster_id = character(),
      source_cell_id = character(), target_anchor_id = character(),
      source_n = numeric(), source_weight = numeric(), target_n_before = numeric(),
      target_weight_before = numeric(), merged_n = numeric(), merged_weight = numeric(),
      merged_unit_weight = numeric(), stringsAsFactors = FALSE
    )
  }

  list(
    final_cells = final_df,
    cell_map = cell_map_df,
    merge_steps = merge_steps_df,
    contributions = contrib
  )
}

.assert_merge_fit <- function(fit) {
  if (!inherits(fit, "mergecalib_fit")) {
    .mc_stop("mergecalib_error_input", "`fit` must be a mergecalib_fit object.")
  }
  fit
}

#' Calculate initial and final proportions by arbitrary dimensions
#'
#' @param fit A fitted `mergecalib_fit` object.
#' @param by Character vector of columns in the original data.
#' @return Long-form data frame with one row per group and grade.
#' @export
calculate_results <- function(fit, by) {
  fit <- .assert_merge_fit(fit)
  contrib <- fit$outputs$contributions
  spec <- fit$spec
  if (!length(by) || !all(by %in% names(contrib))) {
    .mc_stop("mergecalib_error_input", "`by` must be one or more columns present in the original data.")
  }
  grade_names <- names(spec$grades)
  contrib$.sample_n <- contrib[[spec$n]]
  num_cols <- c(
    ".sample_n", "initial_denominator", "final_denominator",
    paste0("initial_num_", grade_names),
    paste0("final_num_", grade_names)
  )
  agg <- stats::aggregate(
    contrib[num_cols],
    by = contrib[by],
    FUN = sum,
    na.rm = TRUE
  )
  rows <- vector("list", nrow(agg) * length(grade_names))
  z <- 0L
  for (i in seq_len(nrow(agg))) {
    for (g in grade_names) {
      z <- z + 1L
      ini_d <- agg$initial_denominator[i]
      fin_d <- agg$final_denominator[i]
      row <- agg[i, by, drop = FALSE]
      row$grade <- g
      row$sample_n <- agg$.sample_n[i]
      row$initial_weighted_n <- ini_d
      row$final_weighted_n <- fin_d
      row$initial_weighted_grade_n <- agg[[paste0("initial_num_", g)]][i]
      row$final_weighted_grade_n <- agg[[paste0("final_num_", g)]][i]
      row$initial_proportion <- if (ini_d > 0) row$initial_weighted_grade_n / ini_d else NA_real_
      row$final_proportion <- if (fin_d > 0) row$final_weighted_grade_n / fin_d else NA_real_
      rows[[z]] <- row
    }
  }
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

.compute_target_results <- function(fit) {
  data <- fit$data
  targets <- fit$targets
  spec <- fit$spec
  contrib <- fit$outputs$contributions
  membership <- .target_membership_matrix(data, targets, spec)
  grade_names <- names(spec$grades)
  rows <- vector("list", nrow(targets))
  for (t in seq_len(nrow(targets))) {
    use <- membership[, t]
    g <- as.character(targets$grade[t])
    ini_d <- sum(contrib$initial_denominator[use])
    fin_d <- sum(contrib$final_denominator[use])
    ini_y <- sum(contrib[[paste0("initial_num_", g)]][use])
    fin_y <- sum(contrib[[paste0("final_num_", g)]][use])
    ini_p <- if (ini_d > 0) ini_y / ini_d else NA_real_
    fin_p <- if (fin_d > 0) fin_y / fin_d else NA_real_
    eff_l <- max(0, targets$lower[t] - fit$delta)
    eff_u <- min(1, targets$upper[t] + fit$delta)
    original_status <- if (fin_p < targets$lower[t] - 1e-6) "below" else if (
      fin_p > targets$upper[t] + 1e-6
    ) "above" else "within"
    effective_status <- if (fin_p < eff_l - 1e-6) "below" else if (
      fin_p > eff_u + 1e-6
    ) "above" else "within"
    row <- targets[t, setdiff(names(targets), ".target_row"), drop = FALSE]
    row$initial_weighted_n <- ini_d
    row$final_weighted_n <- fin_d
    row$initial_proportion <- ini_p
    row$final_proportion <- fin_p
    row$effective_lower <- eff_l
    row$effective_upper <- eff_u
    row$distance_to_original_interval <- max(targets$lower[t] - fin_p, fin_p - targets$upper[t], 0)
    row$original_status <- original_status
    row$status <- effective_status
    row$zero_sample_unallocated_weight_initial <- sum(
      data[[spec$weight]][use & data[[spec$n]] == 0]
    )
    rows[[t]] <- row
  }
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

#' Original-cell to final-cluster mapping
#' @param fit A fitted model.
#' @export
cell_map <- function(fit) {
  fit <- .assert_merge_fit(fit)
  fit$outputs$cell_map
}

#' Ordered merge operations
#' @param fit A fitted model.
#' @export
merge_plan <- function(fit) {
  fit <- .assert_merge_fit(fit)
  fit$outputs$merge_steps
}

#' Final positive-sample merged cells
#' @param fit A fitted model.
#' @export
final_cells <- function(fit) {
  fit <- .assert_merge_fit(fit)
  fit$outputs$final_cells
}

#' Target audit results
#' @param fit A fitted model.
#' @export
target_results <- function(fit) {
  fit <- .assert_merge_fit(fit)
  .compute_target_results(fit)
}

#' Province-level grade proportions
#' @param fit A fitted model.
#' @export
province_results <- function(fit) {
  fit <- .assert_merge_fit(fit)
  calculate_results(fit, fit$spec$province)
}

#' National fine-cell grade proportions
#' @param fit A fitted model.
#' @param include_zero Whether to include original demographic combinations with zero observed sample.
#' @export
national_cell_results <- function(fit, include_zero = FALSE) {
  fit <- .assert_merge_fit(fit)
  out <- calculate_results(fit, unname(fit$spec$groups))
  if (!isTRUE(include_zero)) out <- out[out$sample_n > 0, , drop = FALSE]
  rownames(out) <- NULL
  out
}

#' Audit a fitted merge plan
#'
#' @param fit A fitted `mergecalib_fit` object.
#' @param tolerance Numeric audit tolerance.
#' @return A list containing `valid`, `issues`, and diagnostics.
#' @export
audit_merge_fit <- function(fit, tolerance = 1e-6) {
  fit <- .assert_merge_fit(fit)
  issues <- character()
  final <- fit$outputs$final_cells
  map <- fit$outputs$cell_map
  data <- fit$data
  spec <- fit$spec

  if (any(final$final_n <= 0)) issues <- c(issues, "a final merged cell has sample size 0")
  if (nrow(map) != nrow(data)) issues <- c(issues, "the original-cell mapping has an incomplete number of rows")
  if (anyDuplicated(map[[spec$id]])) issues <- c(issues, "an original cell is duplicated in the mapping table")
  if (abs(sum(final$final_n) - sum(data[[spec$n]])) > tolerance) {
    issues <- c(issues, "the total sample size is not conserved")
  }
  if (abs(sum(final$final_weight) - sum(data[[spec$weight]])) > tolerance) {
    issues <- c(issues, "the total weight is not conserved")
  }
  grade_names <- names(spec$grades)
  final_grade_sum <- rowSums(final[paste0("count_", grade_names)])
  if (any(abs(final_grade_sum - final$final_n) > tolerance)) {
    issues <- c(issues, "the grade counts of a final cluster do not sum to its final sample size")
  }
  for (g in grade_names) {
    input_total <- sum(data[[unname(spec$grades[[g]])]])
    output_total <- sum(final[[paste0("count_", g)]])
    if (abs(input_total - output_total) > tolerance) {
      issues <- c(issues, paste0("the total count of grade ", g, " is not conserved"))
    }
  }
  tr <- .compute_target_results(fit)
  if (any(tr$status != "within")) issues <- c(issues, "a proportion falls outside its effective target interval")
  if (!isTRUE(fit$model_check$valid)) issues <- c(issues, "the final binary solution violates the MILP constraints")

  list(
    valid = !length(issues),
    issues = issues,
    zero_sample_original_cells = sum(data[[spec$n]] == 0),
    zero_sample_final_cells = sum(final$final_n == 0),
    original_cell_count = nrow(data),
    final_cell_count = nrow(final),
    total_sample = sum(final$final_n),
    total_weight = sum(final$final_weight),
    target_rows = nrow(tr),
    targets_within_original_range = sum(tr$original_status == "within"),
    targets_within_effective_range = sum(tr$status == "within"),
    minimum_uniform_delta = fit$delta,
    candidate_level = fit$candidate_level,
    candidate_count = nrow(fit$candidates),
    selected_cluster_count = nrow(final),
    maximum_final_unit_weight = max(final$final_unit_weight),
    maximum_final_weight_ratio = max(final$max_weight_ratio),
    all_lexicographic_stages_optimal = all(vapply(
      fit$stage_results, function(z) isTRUE(z$optimal), logical(1)
    )),
    model_check = fit$model_check
  )
}

#' Export all merge results to a directory
#'
#' @param fit A fitted `mergecalib_fit` object.
#' @param path Output directory.
#' @param overwrite Whether existing result files may be replaced.
#' @param include_zero_national Whether to include zero-observation original
#'   demographic combinations in the national fine-cell table.
#' @param save_fit Whether to save the complete fitted object as an RDS file.
#' @return Invisibly returns the normalized output directory.
#' @export
export_merge_results <- function(
  fit,
  path,
  overwrite = FALSE,
  include_zero_national = FALSE,
  save_fit = TRUE
) {
  fit <- .assert_merge_fit(fit)
  if (!is.character(path) || length(path) != 1L || !nzchar(path)) {
    .mc_stop("mergecalib_error_input", "`path` must be a single non-empty directory path.")
  }
  if (!dir.exists(path)) dir.create(path, recursive = TRUE, showWarnings = FALSE)
  if (!dir.exists(path)) .mc_stop("mergecalib_error_input", "Could not create the output directory: ", path, ".")

  tables <- list(
    cell_map = cell_map(fit),
    merge_plan = merge_plan(fit),
    final_cells = final_cells(fit),
    target_results = target_results(fit),
    province_results = province_results(fit),
    national_cell_results = national_cell_results(fit, include_zero_national)
  )
  files <- file.path(path, paste0(names(tables), ".csv"))
  diagnostics_file <- file.path(path, "diagnostics.csv")
  rds_file <- file.path(path, "mergecalib_fit.rds")
  existing <- c(
    files[file.exists(files)],
    diagnostics_file[file.exists(diagnostics_file)],
    if (save_fit && file.exists(rds_file)) rds_file
  )
  if (length(existing) && !isTRUE(overwrite)) {
    .mc_stop("mergecalib_error_input", "The following files already exist; set overwrite = TRUE to replace them: ",
             paste(basename(existing), collapse = ", "), ".")
  }
  for (nm in names(tables)) {
    utils::write.csv(
      tables[[nm]], file.path(path, paste0(nm, ".csv")),
      row.names = FALSE, fileEncoding = "UTF-8"
    )
  }

  audit <- audit_merge_fit(fit)
  scalar <- vapply(audit, function(z) length(z) == 1L && !is.list(z), logical(1))
  diagnostics <- data.frame(
    metric = names(audit)[scalar],
    value = vapply(audit[scalar], as.character, character(1)),
    stringsAsFactors = FALSE
  )
  utils::write.csv(
    diagnostics, diagnostics_file,
    row.names = FALSE, fileEncoding = "UTF-8"
  )
  if (isTRUE(save_fit)) saveRDS(fit, rds_file)
  invisible(normalizePath(path, winslash = "/", mustWork = TRUE))
}
