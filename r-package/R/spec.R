#' Define the data schema used by mergecalib
#'
#' @param province Column containing province identifiers.
#' @param id Unique original-cell identifier column.
#' @param n Sample-size column.
#' @param weight Total-weight column for each original cell.
#' @param grades Named character vector mapping grade labels to count columns.
#' @param groups Named character vector mapping demographic dimensions to columns.
#' @param ordered_groups Names in `groups` that have an ordinal distance.
#' @param level_orders Optional named list giving explicit level order for ordinal dimensions.
#' @return An object of class `mergecalib_spec`.
#' @export
merge_spec <- function(
  province = "province",
  id = "cell_id",
  n = "n",
  weight = "weight",
  grades = c(A = "A", B = "B", C = "C", D = "D"),
  groups = c(sex = "sex", urban = "urban", age = "age", education = "education"),
  ordered_groups = c("age", "education"),
  level_orders = list()
) {
  if (is.null(names(grades)) || any(names(grades) == "")) {
    .mc_stop("mergecalib_error_internal", "`grades` must be a named character vector, e.g. c(A='A', B='B', C='C', D='D').")
  }
  if (is.null(names(groups)) || any(names(groups) == "")) {
    .mc_stop("mergecalib_error_internal", "`groups` must be a named character vector.")
  }
  if (!all(ordered_groups %in% names(groups))) {
    .mc_stop("mergecalib_error_internal", "`ordered_groups` must be a subset of the names of `groups`.")
  }
  structure(
    list(
      province = province,
      id = id,
      n = n,
      weight = weight,
      grades = grades,
      groups = groups,
      ordered_groups = ordered_groups,
      level_orders = level_orders
    ),
    class = "mergecalib_spec"
  )
}

.all_dimension_columns <- function(spec) {
  c(spec$province, unname(spec$groups))
}

.required_columns <- function(spec) {
  unique(c(
    spec$province, spec$id, spec$n, spec$weight,
    unname(spec$grades), unname(spec$groups)
  ))
}

#' Default staged candidate-generation settings
#'
#' The levels expand deterministically from local pair merges to broader clusters.
#' @return A list of candidate-control lists.
#' @export
default_candidate_levels <- function() {
  list(
    local_pairs = list(
      max_cluster_size = 2L,
      max_neighbors = 4L,
      max_distance = 2,
      max_combinations_per_cell = 20L,
      include_province_fallback = FALSE
    ),
    local_small = list(
      max_cluster_size = 3L,
      max_neighbors = 6L,
      max_distance = 4,
      max_combinations_per_cell = 60L,
      include_province_fallback = FALSE
    ),
    broad = list(
      max_cluster_size = 4L,
      max_neighbors = 8L,
      max_distance = Inf,
      max_combinations_per_cell = 120L,
      include_province_fallback = FALSE
    ),
    widest = list(
      max_cluster_size = 6L,
      max_neighbors = 12L,
      max_distance = Inf,
      max_combinations_per_cell = 250L,
      include_province_fallback = TRUE
    )
  )
}
