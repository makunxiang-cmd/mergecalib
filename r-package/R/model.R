.normalize_targets <- function(targets, spec) {
  targets <- as.data.frame(targets, stringsAsFactors = FALSE)
  dims <- .all_dimension_columns(spec)
  for (col in setdiff(dims, names(targets))) targets[[col]] <- NA_character_
  if (!"scope" %in% names(targets)) targets$scope <- "custom"
  if (!"target_name" %in% names(targets)) targets$target_name <- targets$target_id
  targets$.target_row <- seq_len(nrow(targets))
  targets
}

.target_membership_matrix <- function(data, targets, spec) {
  dims <- .all_dimension_columns(spec)
  out <- matrix(FALSE, nrow(data), nrow(targets))
  for (t in seq_len(nrow(targets))) {
    out[, t] <- .match_rows(data, targets[t, , drop = FALSE], dims)
  }
  out
}

.candidate_incidence <- function(candidates, n_cells) {
  member_lengths <- lengths(candidates$members)
  Matrix::sparseMatrix(
    i = unlist(candidates$members, use.names = FALSE),
    j = rep.int(seq_len(nrow(candidates)), member_lengths),
    x = 1,
    dims = c(n_cells, nrow(candidates))
  )
}

.target_coefficients <- function(data, targets, candidates, spec, delta = 0,
                                 membership = NULL, incidence = NULL) {
  if (is.null(membership)) membership <- .target_membership_matrix(data, targets, spec)
  nc <- nrow(candidates)
  nt <- nrow(targets)
  lower_coef <- vector("list", nt)
  upper_coef <- vector("list", nt)
  denom_coef <- vector("list", nt)
  numer_coef <- vector("list", nt)

  n <- data[[spec$n]]
  if (is.null(incidence)) incidence <- .candidate_incidence(candidates, nrow(data))
  for (t in seq_len(nt)) {
    grade_col <- unname(spec$grades[as.character(targets$grade[t])])
    lower <- max(0, targets$lower[t] - delta)
    upper <- min(1, targets$upper[t] + delta)
    member_flag <- as.numeric(membership[, t])
    cluster_n <- as.numeric(crossprod(incidence, n * member_flag))
    cluster_y <- as.numeric(crossprod(incidence, data[[grade_col]] * member_flag))
    d <- candidates$unit_weight * cluster_n
    y <- candidates$unit_weight * cluster_y
    lc <- y - lower * d
    uc <- y - upper * d
    # Positive row scaling improves numerical stability without changing the model.
    scale_l <- max(1, max(abs(lc)))
    scale_u <- max(1, max(abs(uc)))
    lower_coef[[t]] <- lc / scale_l
    upper_coef[[t]] <- uc / scale_u
    denom_coef[[t]] <- d
    numer_coef[[t]] <- y
  }
  list(
    lower = lower_coef,
    upper = upper_coef,
    denominator = denom_coef,
    numerator = numer_coef,
    membership = membership,
    incidence = incidence
  )
}

.build_milp <- function(data, targets, candidates, spec, delta = 0,
                        objective = NULL, cuts = list(), membership = NULL) {
  nc <- nrow(candidates)
  nr_cells <- nrow(data)
  nt <- nrow(targets)
  if (is.null(objective)) objective <- rep(0, nc)
  if (length(objective) != nc) .mc_stop("Internal error: objective length does not match the number of candidate clusters.")

  incidence <- .candidate_incidence(candidates, nr_cells)
  coef <- .target_coefficients(
    data, targets, candidates, spec, delta, membership, incidence
  )
  ncuts <- length(cuts)
  nrows <- nr_cells + 2L * nt + ncuts
  member_lengths <- lengths(candidates$members)
  i_chunks <- list(unlist(candidates$members, use.names = FALSE))
  j_chunks <- list(rep.int(seq_len(nc), member_lengths))
  x_chunks <- list(rep.int(1, sum(member_lengths)))
  lhs <- rep(-Inf, nrows)
  rhs <- rep(Inf, nrows)
  row_names <- character(nrows)

  # Exact-cover constraints: every original cell appears in exactly one selected cluster.
  lhs[seq_len(nr_cells)] <- 1
  rhs[seq_len(nr_cells)] <- 1
  row_names[seq_len(nr_cells)] <- paste0("cover:", data[[spec$id]])

  offset <- nr_cells
  for (t in seq_len(nt)) {
    row_l <- offset + 2L * t - 1L
    row_u <- offset + 2L * t
    nz_l <- which(coef$lower[[t]] != 0)
    nz_u <- which(coef$upper[[t]] != 0)
    if (length(nz_l)) {
      i_chunks[[length(i_chunks) + 1L]] <- rep.int(row_l, length(nz_l))
      j_chunks[[length(j_chunks) + 1L]] <- nz_l
      x_chunks[[length(x_chunks) + 1L]] <- coef$lower[[t]][nz_l]
    }
    if (length(nz_u)) {
      i_chunks[[length(i_chunks) + 1L]] <- rep.int(row_u, length(nz_u))
      j_chunks[[length(j_chunks) + 1L]] <- nz_u
      x_chunks[[length(x_chunks) + 1L]] <- coef$upper[[t]][nz_u]
    }
    lhs[row_l] <- 0
    rhs[row_u] <- 0
    row_names[row_l] <- paste0("target_lower:", targets$target_id[t], ":", targets$grade[t])
    row_names[row_u] <- paste0("target_upper:", targets$target_id[t], ":", targets$grade[t])
  }

  if (ncuts) {
    for (k in seq_len(ncuts)) {
      row <- nr_cells + 2L * nt + k
      v <- cuts[[k]]$coef
      nz <- which(v != 0)
      if (length(nz)) {
        scale <- max(1, max(abs(v[nz])))
        i_chunks[[length(i_chunks) + 1L]] <- rep.int(row, length(nz))
        j_chunks[[length(j_chunks) + 1L]] <- nz
        x_chunks[[length(x_chunks) + 1L]] <- v[nz] / scale
        lhs[row] <- cuts[[k]]$lhs / scale
        rhs[row] <- cuts[[k]]$rhs / scale
      } else {
        lhs[row] <- cuts[[k]]$lhs
        rhs[row] <- cuts[[k]]$rhs
      }
      row_names[row] <- cuts[[k]]$name
    }
  }

  ii <- unlist(i_chunks, use.names = FALSE)
  jj <- unlist(j_chunks, use.names = FALSE)
  xx <- unlist(x_chunks, use.names = FALSE)
  A <- Matrix::sparseMatrix(
    i = ii,
    j = jj,
    x = xx,
    dims = c(nrows, nc),
    dimnames = list(row_names, candidates$cluster_id)
  )

  list(
    L = as.numeric(objective),
    lower = rep(0, nc),
    upper = rep(1, nc),
    A = A,
    lhs = lhs,
    rhs = rhs,
    types = rep("I", nc),
    target_coefficients = coef,
    delta = delta
  )
}

.solve_highs <- function(model, solver_control = list(), start = NULL) {
  .assert_installed("highs")
  defaults <- list(
    threads = 1L,
    time_limit = Inf,
    log_to_console = FALSE,
    random_seed = 0L,
    parallel = "off",
    presolve = "on",
    mip_rel_gap = 1e-7,
    mip_abs_gap = 1e-7
  )
  ctrl <- utils::modifyList(defaults, solver_control)
  high_ctrl <- do.call(highs::highs_control, ctrl)
  highs::highs_solve(
    L = model$L,
    lower = model$lower,
    upper = model$upper,
    A = model$A,
    lhs = model$lhs,
    rhs = model$rhs,
    types = model$types,
    maximum = FALSE,
    start = start,
    control = high_ctrl
  )
}

.check_solution_constraints <- function(model, solution, tolerance = 1e-6) {
  ax <- as.numeric(model$A %*% solution)
  low_ok <- is.infinite(model$lhs) | ax >= model$lhs - tolerance
  up_ok <- is.infinite(model$rhs) | ax <= model$rhs + tolerance
  list(
    valid = all(low_ok & up_ok),
    max_lower_violation = if (any(!low_ok)) max(model$lhs[!low_ok] - ax[!low_ok]) else 0,
    max_upper_violation = if (any(!up_ok)) max(ax[!up_ok] - model$rhs[!up_ok]) else 0,
    violated_rows = rownames(model$A)[!(low_ok & up_ok)]
  )
}

.feasibility_solve <- function(data, targets, candidates, spec, delta,
                               solver_control, membership = NULL) {
  model <- .build_milp(
    data = data,
    targets = targets,
    candidates = candidates,
    spec = spec,
    delta = delta,
    objective = rep(0, nrow(candidates)),
    membership = membership
  )
  sol <- .solve_highs(model, solver_control)
  available <- .solution_available(sol, nrow(candidates))
  valid <- FALSE
  check <- NULL
  if (available) {
    x <- as.numeric(sol$primal_solution > 0.5)
    check <- .check_solution_constraints(model, x)
    valid <- isTRUE(check$valid)
  }
  list(feasible = available && valid, solution = sol, model = model, check = check)
}
