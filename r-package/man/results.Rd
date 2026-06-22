\name{mergecalib-results}
\alias{cell_map}
\alias{merge_plan}
\alias{final_cells}
\alias{target_results}
\alias{province_results}
\alias{national_cell_results}
\alias{calculate_results}
\alias{audit_merge_fit}
\alias{export_merge_results}
\title{Extract and audit mergecalib results}
\usage{
cell_map(fit)
merge_plan(fit)
final_cells(fit)
target_results(fit)
province_results(fit)
national_cell_results(fit, include_zero = FALSE)
calculate_results(fit, by)
audit_merge_fit(fit, tolerance = 1e-6)
export_merge_results(
  fit, path, overwrite = FALSE, include_zero_national = FALSE,
  save_fit = TRUE
)
}
\arguments{
\item{fit}{A fitted \code{mergecalib_fit} object.}
\item{include_zero}{Whether to show original demographic combinations with zero observed sample.}
\item{by}{Original-data columns used for aggregation.}
\item{tolerance}{Audit tolerance.}
\item{path}{Output directory.}
\item{overwrite}{Whether existing files may be replaced.}
\item{include_zero_national}{Whether to export zero-observation national fine cells.}
\item{save_fit}{Whether to save the complete fitted object as RDS.}
}
\value{
The extractors return data frames. \code{audit_merge_fit()} returns a list with
validity, issues, conservation checks, target checks, and zero-sample counts.
}
\description{
Extracts the original-to-final mapping, ordered merge plan, final positive-sample
clusters, target results, province results, national fine-cell results, and
a complete audit.
}
