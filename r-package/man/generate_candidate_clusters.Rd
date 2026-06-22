\name{generate_candidate_clusters}
\alias{generate_candidate_clusters}
\title{Generate deterministic candidate merged cells}
\usage{
generate_candidate_clusters(
  data, spec = merge_spec(), max_cluster_size = 4L, max_neighbors = 8L,
  max_distance = Inf, max_combinations_per_cell = 120L,
  distance_weights = NULL, max_unit_weight = Inf,
  max_weight_ratio = Inf, include_province_fallback = FALSE
)
}
\arguments{
\item{data}{Cell-level data.}
\item{spec}{A schema from \code{merge_spec()}.}
\item{max_cluster_size}{Maximum ordinary candidate size.}
\item{max_neighbors}{Nearest cells considered per seed.}
\item{max_distance}{Maximum seed-to-member demographic distance.}
\item{max_combinations_per_cell}{Combination cap per seed.}
\item{distance_weights}{Named demographic-distance weights.}
\item{max_unit_weight}{Optional final unit-weight upper bound.}
\item{max_weight_ratio}{Optional member-to-final unit-weight ratio bound.}
\item{include_province_fallback}{Whether to add the full-province candidate.}
}
\value{A data frame with list-columns \code{members} and \code{grade_totals}.}
\description{
Generates within-province candidates. Zero-sample singletons are forbidden and
a deterministic zero-absorption fallback partition is added.
}
