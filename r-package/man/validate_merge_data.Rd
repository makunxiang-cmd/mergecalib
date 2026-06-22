\name{validate_merge_data}
\alias{validate_merge_data}
\title{Validate cell data and target intervals}
\usage{validate_merge_data(data, targets = NULL, spec = merge_spec(), tolerance = 1e-8)}
\arguments{
\item{data}{Cell-level data frame.}
\item{targets}{Target interval data frame or \code{NULL}.}
\item{spec}{A schema from \code{merge_spec()}.}
\item{tolerance}{Numeric tolerance.}
}
\value{Invisibly returns \code{TRUE}; otherwise stops.}
\description{
Checks counts, weights, identifiers, target consistency, target estimability,
and the requirement that every province has at least one positive-sample cell.
}
