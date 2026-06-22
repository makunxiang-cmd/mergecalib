\name{example_merge_data}
\alias{example_merge_data}
\alias{example_merge_targets}
\title{Example data and feasible target intervals}
\usage{
example_merge_data()
example_merge_targets(
  data = example_merge_data(),
  spec = merge_spec(level_orders = list(age = c("18-39", "40+"),
    education = c("low", "high"))),
  half_width = 0.02
)
}
\arguments{
\item{data}{Cell data.}
\item{spec}{A schema from \code{merge_spec()}.}
\item{half_width}{Target interval half-width.}
}
\value{A cell data frame or target data frame.}
\description{
Creates a deterministic demonstration dataset containing positive-weight
zero-sample cells and targets known to be feasible under a full-province merge.
}
