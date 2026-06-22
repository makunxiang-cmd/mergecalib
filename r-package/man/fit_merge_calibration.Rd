\name{fit_merge_calibration}
\alias{fit_merge_calibration}
\title{Fit a deterministic cell-merging calibration model}
\usage{
fit_merge_calibration(
  data, targets, spec = merge_spec(),
  candidate_levels = default_candidate_levels(), candidate_control = list(),
  objective_order = c("moved_n", "demo_distance", "heterogeneity",
    "weight_distortion", "merge_count"), relax_targets = TRUE,
  max_delta = 0.1, delta_tolerance = 1e-4,
  lex_tolerance_abs = 1e-7, lex_tolerance_rel = 1e-8,
  solver_control = list()
)
}
\arguments{
\item{data}{Cell-level input data.}
\item{targets}{Target table containing \code{target_id}, \code{grade}, \code{lower}, and \code{upper}.}
\item{spec}{A schema from \code{merge_spec()}.}
\item{candidate_levels}{Staged candidate settings.}
\item{candidate_control}{Common candidate-generation controls.}
\item{objective_order}{Lexicographic objective columns.}
\item{relax_targets}{Search for minimum uniform relaxation if strict targets are infeasible.}
\item{max_delta}{Maximum uniform relaxation.}
\item{delta_tolerance}{Relaxation-search tolerance.}
\item{lex_tolerance_abs}{Absolute lexicographic fixing tolerance.}
\item{lex_tolerance_rel}{Relative lexicographic fixing tolerance.}
\item{solver_control}{Options passed to \code{highs::highs_control()}.}
}
\value{An object of class \code{mergecalib_fit}.}
\description{
Selects a strict once-only partition of original cells using a mixed-integer
linear program. All selected final clusters have positive sample size.
}
\examples{
\dontrun{
spec <- merge_spec(level_orders = list(
  age = c("18-39", "40+"), education = c("low", "high")
))
dat <- example_merge_data()
tar <- example_merge_targets(dat, spec)
fit <- fit_merge_calibration(dat, tar, spec)
print(fit)
}
}
