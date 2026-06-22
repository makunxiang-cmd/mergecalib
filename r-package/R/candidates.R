.encode_group <- function(x, group_name, spec) {
  if (group_name %in% spec$ordered_groups) {
    explicit <- spec$level_orders[[group_name]]
    if (!is.null(explicit)) {
      code <- match(as.character(x), as.character(explicit))
      if (anyNA(code)) {
        unknown <- unique(as.character(x)[is.na(code)])
        .mc_stop("mergecalib_error_input", "Ordinal variable `", group_name, "` has values not listed in level_orders: ",
                 paste(unknown, collapse = ", "), ".")
      }
      return(as.numeric(code))
    }
    if (is.factor(x) && is.ordered(x)) return(as.numeric(x))
    if (is.numeric(x)) return(as.numeric(x))
    lev <- sort(unique(as.character(x)), method = "radix")
    return(as.numeric(match(as.character(x), lev)))
  }
  as.character(x)
}

.distance_spec_global_ordered_levels <- function(data, spec) {
  out <- spec
  if (is.null(out$level_orders)) out$level_orders <- list()
  for (g in spec$ordered_groups) {
    explicit <- g %in% names(out$level_orders) && !is.null(out$level_orders[[g]])
    if (explicit) next

    col <- spec$groups[[g]]
    x <- data[[col]]
    if (is.factor(x) && is.ordered(x)) {
      out$level_orders[[g]] <- levels(x)
    } else if (!is.numeric(x)) {
      out$level_orders[[g]] <- sort(unique(as.character(x)), method = "radix")
    }
  }
  out
}

.distance_matrix_block <- function(data, spec, distance_weights = NULL) {
  group_names <- names(spec$groups)
  if (is.null(distance_weights)) {
    distance_weights <- stats::setNames(rep(1, length(group_names)), group_names)
    distance_weights[setdiff(group_names, spec$ordered_groups)] <- 2
  }
  missing_weights <- setdiff(group_names, names(distance_weights))
  if (length(missing_weights)) distance_weights[missing_weights] <- 1

  nr <- nrow(data)
  out <- matrix(0, nr, nr)
  for (g in group_names) {
    col <- spec$groups[[g]]
    z <- .encode_group(data[[col]], g, spec)
    if (g %in% spec$ordered_groups) {
      component <- abs(outer(z, z, "-"))
    } else {
      component <- outer(z, z, FUN = function(a, b) as.numeric(a != b))
    }
    out <- out + as.numeric(distance_weights[[g]]) * component
  }
  diag(out) <- 0
  out
}

.dist_lookup_block <- function(dist_mat, global_to_local) {
  function(i, j) {
    ii <- global_to_local[as.character(i)]
    jj <- global_to_local[as.character(j)]
    if (anyNA(ii) || anyNA(jj)) {
      bad <- unique(c(as.character(i)[is.na(ii)], as.character(j)[is.na(jj)]))
      .mc_stop(
        "mergecalib_error_internal",
        "Internal distance lookup received an out-of-block row index: ",
        paste(bad, collapse = ", "),
        "."
      )
    }
    dist_mat[ii, jj]
  }
}

.cluster_metrics <- function(members, data, spec, dist) {
  n <- data[[spec$n]][members]
  w <- data[[spec$weight]][members]
  ids <- as.character(data[[spec$id]][members])
  total_n <- sum(n)
  total_w <- sum(w)
  if (total_n <= 0) return(NULL)
  unit_weight <- total_w / total_n

  anchor_local <- .lex_order(-n, ids)[1]
  anchor <- members[anchor_local]
  anchor_n <- n[anchor_local]
  moved_n <- total_n - anchor_n
  demo_distance <- sum(pmax(n, 1) * dist(members, anchor))

  grade_cols <- unname(spec$grades)
  totals <- vapply(grade_cols, function(col) sum(data[[col]][members]), numeric(1))
  q_cluster <- totals / total_n
  heterogeneity <- 0
  for (j in seq_along(members)) {
    if (n[j] > 0) {
      qj <- vapply(grade_cols, function(col) data[[col]][members[j]] / n[j], numeric(1))
      heterogeneity <- heterogeneity + n[j] * sum((qj - q_cluster)^2)
    }
  }

  weight_distortion <- 0
  ratios <- numeric(0)
  for (j in seq_along(members)) {
    if (n[j] > 0) {
      initial_unit <- w[j] / n[j]
      weight_distortion <- weight_distortion + n[j] * log(unit_weight / initial_unit)^2
      ratios <- c(ratios, unit_weight / initial_unit, initial_unit / unit_weight)
    }
  }

  list(
    members = sort(as.integer(members)),
    province = as.character(data[[spec$province]][members[1]]),
    n_total = total_n,
    weight_total = total_w,
    unit_weight = unit_weight,
    anchor_index = anchor,
    anchor_id = as.character(data[[spec$id]][anchor]),
    moved_n = moved_n,
    demo_distance = demo_distance,
    heterogeneity = heterogeneity,
    weight_distortion = weight_distortion,
    merge_count = length(members) - 1L,
    cluster_size = length(members),
    max_weight_ratio = if (length(ratios)) max(ratios) else 1,
    grade_totals = totals
  )
}

.add_candidate <- function(store, members, data, spec, dist,
                           max_unit_weight = Inf, max_weight_ratio = Inf,
                           force = FALSE) {
  members <- sort(unique(as.integer(members)))
  if (!length(members)) return(store)
  key <- paste(members, collapse = ":")
  if (!is.null(store[[key]])) return(store)
  metric <- .cluster_metrics(members, data, spec, dist)
  if (is.null(metric)) return(store)
  if (!force && (metric$unit_weight > max_unit_weight ||
                 metric$max_weight_ratio > max_weight_ratio)) {
    return(store)
  }
  store[[key]] <- metric
  store
}

.combination_candidates <- function(seed, pool, max_add, max_combinations,
                                    dist, data, spec) {
  if (!length(pool) || max_add < 1L) return(list())
  out <- list()
  rank_id <- 0L
  for (k in seq_len(min(max_add, length(pool)))) {
    cmb <- utils::combn(pool, k, simplify = FALSE)
    if (!length(cmb)) next
    score <- vapply(cmb, function(z) {
      sum(dist(seed, z)) + 1e-9 * sum(data[[spec$n]][z])
    }, numeric(1))
    ord <- order(score, vapply(cmb, function(z) paste(z, collapse = ":"), character(1)),
                 method = "radix")
    for (j in ord) {
      rank_id <- rank_id + 1L
      if (rank_id > max_combinations) return(out)
      out[[length(out) + 1L]] <- c(seed, cmb[[j]])
    }
  }
  out
}

#' Generate deterministic candidate merged cells
#'
#' Candidate clusters are generated only within provinces. Positive-sample
#' singletons are retained, while zero-sample singletons are forbidden. A
#' deterministic zero-absorption fallback is always added, which guarantees
#' that the candidate set contains at least one partition whose final clusters
#' all have positive sample size, provided each province has at least one
#' positive-sample original cell.
#'
#' @param data Cell-level data.
#' @param spec A `mergecalib_spec`.
#' @param max_cluster_size Maximum ordinary candidate size.
#' @param max_neighbors Number of nearest cells considered per seed.
#' @param max_distance Maximum seed-to-member demographic distance.
#' @param max_combinations_per_cell Candidate combination cap per seed.
#' @param distance_weights Named distance weights for demographic dimensions.
#' @param max_unit_weight Optional upper bound on final unit weight.
#' @param max_weight_ratio Optional upper bound on unit-weight ratio relative to
#'   positive-sample members.
#' @param include_province_fallback Whether to add the all-cells cluster for each
#'   province.
#' @return A data frame with a list-column named `members`.
#' @export
generate_candidate_clusters <- function(
  data,
  spec = merge_spec(),
  max_cluster_size = 4L,
  max_neighbors = 8L,
  max_distance = Inf,
  max_combinations_per_cell = 120L,
  distance_weights = NULL,
  max_unit_weight = Inf,
  max_weight_ratio = Inf,
  include_province_fallback = FALSE
) {
  validate_merge_data(data, spec = spec)
  max_cluster_size <- as.integer(max_cluster_size)
  max_neighbors <- as.integer(max_neighbors)
  max_combinations_per_cell <- as.integer(max_combinations_per_cell)
  if (max_cluster_size < 2L || max_neighbors < 1L || max_combinations_per_cell < 1L) {
    .mc_stop("mergecalib_error_candidate", "Candidate parameters must satisfy max_cluster_size >= 2, max_neighbors >= 1, and max_combinations_per_cell >= 1.")
  }

  data <- as.data.frame(data, stringsAsFactors = FALSE)
  distance_spec <- .distance_spec_global_ordered_levels(data, spec)
  province <- as.character(data[[spec$province]])
  n <- data[[spec$n]]
  ids <- as.character(data[[spec$id]])
  store <- list()

  for (p in sort(unique(province), method = "radix")) {
    idx <- which(province == p)
    block <- data[idx, , drop = FALSE]
    dist_mat <- .distance_matrix_block(block, distance_spec, distance_weights)
    local_to_global <- idx
    global_to_local <- seq_along(idx)
    names(global_to_local) <- as.character(idx)
    dist_lookup <- .dist_lookup_block(dist_mat, global_to_local)
    local_dist <- function(i, j) dist_mat[i, j]

    n_block <- n[idx]
    ids_block <- ids[idx]
    pos <- which(n_block > 0)
    zero <- which(n_block == 0)

    for (i in pos) {
      store <- .add_candidate(store, local_to_global[i], data, spec, dist_lookup,
                              max_unit_weight, max_weight_ratio)
    }

    seed_order <- .lex_order(n_block, ids_block)
    for (seed in seed_order) {
      other <- setdiff(seq_along(idx), seed)
      if (!length(other)) next
      ord <- .lex_order(dist_mat[seed, other], n_block[other], ids_block[other])
      pool <- other[ord]
      pool <- pool[dist_mat[seed, pool] <= max_distance]
      pool <- utils::head(pool, max_neighbors)
      combos <- .combination_candidates(
        seed = seed,
        pool = pool,
        max_add = max_cluster_size - 1L,
        max_combinations = max_combinations_per_cell,
        dist = local_dist,
        data = block,
        spec = spec
      )
      for (members_local in combos) {
        members_global <- local_to_global[members_local]
        store <- .add_candidate(store, members_global, data, spec, dist_lookup,
                                max_unit_weight, max_weight_ratio)
      }
    }

    # Hard guarantee: every zero-sample cell is assigned to its nearest
    # positive-sample anchor in one deterministic fallback partition.
    if (length(zero)) {
      assigned <- list()
      for (z in zero[.lex_order(ids_block[zero])]) {
        ord <- .lex_order(dist_mat[z, pos], -n_block[pos], ids_block[pos])
        anchor <- pos[ord[1]]
        key <- as.character(anchor)
        assigned[[key]] <- c(assigned[[key]], z)
      }
      for (key in names(assigned)) {
        members_local <- c(as.integer(key), assigned[[key]])
        members_global <- local_to_global[members_local]
        metric <- .cluster_metrics(members_global, data, spec, dist_lookup)
        if (metric$unit_weight > max_unit_weight || metric$max_weight_ratio > max_weight_ratio) {
          .mc_stop(
            "mergecalib_error_weight_bounds",
            "Zero-sample cells in province `", p, "` cannot be absorbed into a positive-sample cell under the current weight bounds. ",
            "Please relax max_unit_weight or max_weight_ratio."
          )
        }
        store <- .add_candidate(store, members_global, data, spec, dist_lookup,
                                max_unit_weight, max_weight_ratio, force = TRUE)
      }
    }

    if (isTRUE(include_province_fallback) && length(idx) > 1L) {
      store <- .add_candidate(store, idx, data, spec, dist_lookup,
                              max_unit_weight, max_weight_ratio)
    }
  }

  if (!length(store)) .mc_stop("mergecalib_error_candidate", "No candidate merged clusters were generated.")
  keys <- sort(names(store), method = "radix")
  store <- store[keys]
  rows <- lapply(seq_along(store), function(i) {
    z <- store[[i]]
    data.frame(
      cluster_id = sprintf("K%07d", i),
      cluster_key = keys[i],
      province = z$province,
      n_total = z$n_total,
      weight_total = z$weight_total,
      unit_weight = z$unit_weight,
      anchor_index = z$anchor_index,
      anchor_id = z$anchor_id,
      moved_n = z$moved_n,
      demo_distance = z$demo_distance,
      heterogeneity = z$heterogeneity,
      weight_distortion = z$weight_distortion,
      merge_count = z$merge_count,
      cluster_size = z$cluster_size,
      max_weight_ratio = z$max_weight_ratio,
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  out$members <- I(lapply(store, `[[`, "members"))
  out$grade_totals <- I(lapply(store, `[[`, "grade_totals"))
  rownames(out) <- NULL

  cover <- tabulate(unlist(out$members), nbins = nrow(data))
  if (any(cover == 0L)) {
    bad <- data[[spec$id]][cover == 0L]
    .mc_stop("mergecalib_error_candidate", "The following original cells are not covered by any candidate cluster: ", paste(bad, collapse = ", "), ".")
  }
  if (any(out$n_total <= 0)) {
    .mc_stop("mergecalib_error_internal", "Internal error: a candidate cluster with sample size 0 was produced.")
  }
  attr(out, "distance_weights") <- distance_weights
  out
}
