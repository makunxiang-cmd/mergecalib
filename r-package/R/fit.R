.find_min_delta <- function(data, targets, candidates, spec, solver_control,
                            max_delta, delta_tolerance, membership) {
  at_max <- .feasibility_solve(
    data, targets, candidates, spec, max_delta, solver_control, membership
  )
  if (!at_max$feasible) {
    return(list(feasible = FALSE, delta = NA_real_, solve = at_max, history = list()))
  }
  low <- 0
  high <- max_delta
  best <- at_max
  history <- list(list(delta = max_delta, feasible = TRUE))
  while ((high - low) > delta_tolerance) {
    mid <- (low + high) / 2
    z <- .feasibility_solve(data, targets, candidates, spec, mid,
                            solver_control, membership)
    history[[length(history) + 1L]] <- list(delta = mid, feasible = z$feasible)
    if (z$feasible) {
      high <- mid
      best <- z
    } else {
      low <- mid
    }
  }
  list(feasible = TRUE, delta = high, solve = best, history = history)
}

.lexicographic_solve <- function(data, targets, candidates, spec, delta,
                                 objective_order, solver_control,
                                 lex_tolerance_abs, lex_tolerance_rel,
                                 membership, start = NULL) {
  cuts <- list()
  stage_results <- list()
  current_start <- start
  last_solution <- NULL
  last_model <- NULL

  for (stage in objective_order) {
    if (!stage %in% names(candidates)) {
      .mc_stop("Unknown lexicographic objective column: `", stage, "`.")
    }
    objective <- as.numeric(candidates[[stage]])
    if (any(!is.finite(objective))) {
      .mc_stop("Lexicographic objective `", stage, "` contains non-finite values.")
    }
    if (all(abs(objective) <= .Machine$double.eps)) {
      stage_results[[stage]] <- list(
        objective = 0,
        status = "skipped_zero_objective",
        optimal = TRUE
      )
      next
    }
    model <- .build_milp(
      data, targets, candidates, spec, delta,
      objective = objective,
      cuts = cuts,
      membership = membership
    )
    sol <- .solve_highs(model, solver_control, start = current_start)
    if (!.solution_available(sol, nrow(candidates))) {
      .mc_stop("Lexicographic stage `", stage, "` did not return a feasible solution. Solver status: ",
               paste(sol$status_message, collapse = " "), ".")
    }
    x <- as.numeric(sol$primal_solution > 0.5)
    check <- .check_solution_constraints(model, x)
    if (!check$valid) {
      .mc_stop("The solver returned a constraint-violating solution at stage `", stage, "`. Maximum violation: ",
               max(check$max_lower_violation, check$max_upper_violation), ".")
    }
    value <- sum(objective * x)
    tolerance <- lex_tolerance_abs + lex_tolerance_rel * max(1, abs(value))
    cuts[[length(cuts) + 1L]] <- list(
      coef = objective,
      lhs = -Inf,
      rhs = value + tolerance,
      name = paste0("lex_cap:", stage)
    )
    stage_results[[stage]] <- list(
      objective = value,
      solver_objective = sol$objective_value,
      status = sol$status_message,
      optimal = .status_is_optimal(sol),
      info = sol$info,
      tolerance = tolerance
    )
    current_start <- x
    last_solution <- sol
    last_model <- model
  }

  if (is.null(last_solution)) {
    last_model <- .build_milp(
      data, targets, candidates, spec, delta,
      objective = rep(0, nrow(candidates)),
      cuts = cuts,
      membership = membership
    )
    last_solution <- .solve_highs(last_model, solver_control, start = current_start)
  }
  list(solution = last_solution, model = last_model, stages = stage_results, cuts = cuts)
}

#' Fit a deterministic cell-merging calibration model
#'
#' @param data Cell-level input data.
#' @param targets Target interval table. It must contain `target_id`, `grade`,
#'   `lower`, and `upper`. Province and demographic columns may be fixed to a
#'   value or set to `NA`/`"*"` as wildcards.
#' @param spec A `mergecalib_spec`.
#' @param candidate_levels Staged candidate settings. Defaults to
#'   `default_candidate_levels()`.
#' @param candidate_control Common arguments passed to
#'   `generate_candidate_clusters()`.
#' @param objective_order Lexicographic objective columns.
#' @param relax_targets If `TRUE`, search for the minimum uniform interval
#'   relaxation when strict targets are infeasible.
#' @param max_delta Maximum allowed uniform relaxation.
#' @param delta_tolerance Binary-search tolerance for relaxation.
#' @param lex_tolerance_abs Absolute tolerance used when fixing a completed
#'   lexicographic stage.
#' @param lex_tolerance_rel Relative tolerance used when fixing a completed
#'   lexicographic stage.
#' @param solver_control Named list passed to `highs::highs_control()`.
#' @return An object of class `mergecalib_fit`.
#' @export
fit_merge_calibration <- function(
  data,
  targets,
  spec = merge_spec(),
  candidate_levels = default_candidate_levels(),
  candidate_control = list(),
  objective_order = c(
    "moved_n", "demo_distance", "heterogeneity",
    "weight_distortion", "merge_count"
  ),
  relax_targets = TRUE,
  max_delta = 0.10,
  delta_tolerance = 1e-4,
  lex_tolerance_abs = 1e-7,
  lex_tolerance_rel = 1e-8,
  solver_control = list()
) {
  .assert_installed("highs")
  .mc_require_consent()
  validate_merge_data(data, targets, spec)
  if (!is.list(candidate_levels) || !length(candidate_levels)) {
    .mc_stop("`candidate_levels` must be a non-empty list.")
  }
  if (is.null(names(candidate_levels))) {
    names(candidate_levels) <- paste0("level", seq_along(candidate_levels))
  } else if (any(names(candidate_levels) == "")) {
    empty <- which(names(candidate_levels) == "")
    names(candidate_levels)[empty] <- paste0("level", empty)
  }
  if (!is.numeric(max_delta) || length(max_delta) != 1L ||
      !is.finite(max_delta) || max_delta < 0 || max_delta > 1) {
    .mc_stop("`max_delta` must be a single number between 0 and 1.")
  }

  data <- as.data.frame(data, stringsAsFactors = FALSE)
  if (".mergecalib_original_row__" %in% names(data)) {
    .mc_stop("The input data contains the reserved column `.mergecalib_original_row__`; please rename it first.")
  }
  data$.mergecalib_original_row__ <- seq_len(nrow(data))
  ord <- .lex_order(
    as.character(data[[spec$province]]),
    data[[spec$n]],
    as.character(data[[spec$id]])
  )
  data <- data[ord, , drop = FALSE]
  rownames(data) <- NULL
  targets <- .normalize_targets(targets, spec)
  target_ord <- .lex_order(as.character(targets$target_id), as.character(targets$grade))
  targets <- targets[target_ord, , drop = FALSE]
  rownames(targets) <- NULL
  membership <- .target_membership_matrix(data, targets, spec)

  attempts <- list()
  strict <- NULL
  chosen_candidates <- NULL
  chosen_level <- NULL
  last_candidates <- NULL

  for (level_name in names(candidate_levels)) {
    level <- candidate_levels[[level_name]]
    args <- c(
      list(data = data, spec = spec),
      candidate_control,
      level
    )
    # Later lists override earlier ones while avoiding duplicated formal names.
    args <- args[!duplicated(names(args), fromLast = TRUE)]
    candidates <- do.call(generate_candidate_clusters, args)
    last_candidates <- candidates
    fs <- .feasibility_solve(
      data, targets, candidates, spec, 0, solver_control, membership
    )
    attempts[[level_name]] <- list(
      candidate_count = nrow(candidates),
      feasible_at_delta_zero = fs$feasible,
      status = fs$solution$status_message
    )
    if (fs$feasible) {
      strict <- fs
      chosen_candidates <- candidates
      chosen_level <- level_name
      break
    }
  }

  relaxation_history <- list()
  if (!is.null(strict)) {
    delta <- 0
    feasibility <- strict
  } else {
    if (!isTRUE(relax_targets)) {
      .mc_stop(
        "The original target intervals are infeasible at every candidate-expansion level. ",
        "Set relax_targets = TRUE to search for the minimum uniform relaxation."
      )
    }
    chosen_candidates <- last_candidates
    chosen_level <- tail(names(candidate_levels), 1L)
    relaxed <- .find_min_delta(
      data, targets, chosen_candidates, spec, solver_control,
      max_delta, delta_tolerance, membership
    )
    relaxation_history <- relaxed$history
    if (!relaxed$feasible) {
      .mc_stop(
        "The model remains infeasible even after relaxing every target interval uniformly on both sides by ", max_delta,
        ". You need to widen the candidate-merge range, relax the weight bounds, or re-check the targets."
      )
    }
    delta <- relaxed$delta
    feasibility <- relaxed$solve
  }

  start <- if (.solution_available(feasibility$solution, nrow(chosen_candidates))) {
    as.numeric(feasibility$solution$primal_solution > 0.5)
  } else NULL
  lex <- .lexicographic_solve(
    data, targets, chosen_candidates, spec, delta,
    objective_order, solver_control,
    lex_tolerance_abs, lex_tolerance_rel,
    membership, start
  )
  x <- as.numeric(lex$solution$primal_solution > 0.5)
  selected <- which(x == 1)
  if (!length(selected)) .mc_stop("Internal error: the final solution selected no merged clusters.")
  if (any(chosen_candidates$n_total[selected] <= 0)) {
    .mc_stop("Internal error: the final solution contains a merged cluster with sample size 0.")
  }
  cover <- tabulate(unlist(chosen_candidates$members[selected]), nbins = nrow(data))
  if (any(cover != 1L)) {
    .mc_stop("Internal error: the final plan does not form an exact one-time cover of the original cells.")
  }

  fit <- list(
    call = match.call(),
    data = data,
    targets = targets,
    spec = spec,
    candidates = chosen_candidates,
    selected_candidate_indices = selected,
    selected_solution = x,
    delta = delta,
    candidate_level = chosen_level,
    attempts = attempts,
    relaxation_history = relaxation_history,
    feasibility_status = feasibility$solution$status_message,
    final_solver_status = lex$solution$status_message,
    final_solver_info = lex$solution$info,
    stage_results = lex$stages,
    objective_order = objective_order,
    solver_control = solver_control,
    model_check = .check_solution_constraints(lex$model, x)
  )
  class(fit) <- "mergecalib_fit"
  fit$outputs <- .build_fit_outputs(fit)
  audit <- audit_merge_fit(fit)
  if (!isTRUE(audit$valid)) {
    .mc_stop("Final audit failed: ", paste(audit$issues, collapse = "; "), ".")
  }
  fit
}
