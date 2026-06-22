#' @export
print.mergecalib_fit <- function(x, ...) {
  audit <- audit_merge_fit(x)
  cat("<mergecalib_fit>\n")
  cat("  Original cells: ", audit$original_cell_count, "\n", sep = "")
  cat("  Final positive-sample cells: ", audit$final_cell_count, "\n", sep = "")
  cat("  Original zero-sample cells: ", audit$zero_sample_original_cells, "\n", sep = "")
  cat("  Final zero-sample cells: ", audit$zero_sample_final_cells, "\n", sep = "")
  cat("  Candidate-expansion level: ", x$candidate_level, "\n", sep = "")
  cat("  Minimum uniform target relaxation: ", .compact_number(x$delta), "\n", sep = "")
  cat("  Solver status: ", paste(x$final_solver_status, collapse = " "), "\n", sep = "")
  cat("  Audit: ", if (audit$valid) "passed" else "failed", "\n", sep = "")
  invisible(x)
}

#' @export
summary.mergecalib_fit <- function(object, ...) {
  audit <- audit_merge_fit(object)
  tr <- target_results(object)
  stage <- lapply(names(object$stage_results), function(nm) {
    z <- object$stage_results[[nm]]
    data.frame(
      stage = nm,
      objective = z$objective,
      optimal = isTRUE(z$optimal),
      status = paste(z$status, collapse = " "),
      stringsAsFactors = FALSE
    )
  })
  stage <- if (length(stage)) do.call(rbind, stage) else data.frame()
  out <- list(
    audit = audit,
    stage_results = stage,
    target_status = table(tr$original_status, useNA = "ifany"),
    effective_target_status = table(tr$status, useNA = "ifany"),
    candidate_attempts = object$attempts
  )
  class(out) <- "summary.mergecalib_fit"
  out
}

#' @export
print.summary.mergecalib_fit <- function(x, ...) {
  cat("mergecalib fit summary\n")
  cat("----------------------\n")
  cat("All final cells positive-sample: ", x$audit$zero_sample_final_cells == 0, "\n", sep = "")
  cat("Minimum uniform target relaxation: ", .compact_number(x$audit$minimum_uniform_delta), "\n", sep = "")
  cat("Targets within effective interval: ", x$audit$targets_within_effective_range,
      "/", x$audit$target_rows, "\n", sep = "")
  if (nrow(x$stage_results)) {
    cat("\nLexicographic objectives:\n")
    print(x$stage_results, row.names = FALSE)
  }
  invisible(x)
}

#' @export
plot.mergecalib_fit <- function(x, type = c("target_error", "cluster_size"), ...) {
  type <- match.arg(type)
  if (type == "target_error") {
    tr <- target_results(x)
    err <- tr$final_proportion - pmin(pmax(tr$final_proportion, tr$lower), tr$upper)
    graphics::barplot(
      err,
      names.arg = paste(tr$target_id, tr$grade, sep = ":"),
      las = 2,
      ylab = "Signed distance from final proportion to original target interval",
      main = "Target interval error",
      ...
    )
    graphics::abline(h = 0, lty = 2)
  } else {
    final <- final_cells(x)
    graphics::hist(
      final$original_cell_count,
      breaks = seq(0.5, max(final$original_cell_count) + 0.5, by = 1),
      xlab = "Number of original cells in each final cell",
      main = "Final merged-cluster size",
      ...
    )
  }
  invisible(x)
}
