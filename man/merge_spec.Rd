\name{merge_spec}
\alias{merge_spec}
\title{Define the mergecalib data schema}
\usage{
merge_spec(
  province = "province", id = "cell_id", n = "n", weight = "weight",
  grades = c(A = "A", B = "B", C = "C", D = "D"),
  groups = c(sex = "sex", urban = "urban", age = "age", education = "education"),
  ordered_groups = c("age", "education"), level_orders = list()
)
}
\arguments{
\item{province}{Province column name.}
\item{id}{Unique original-cell identifier column.}
\item{n}{Sample-size column.}
\item{weight}{Cell total-weight column.}
\item{grades}{Named vector mapping grade labels to count columns.}
\item{groups}{Named vector mapping demographic dimensions to columns.}
\item{ordered_groups}{Dimensions treated as ordinal.}
\item{level_orders}{Optional explicit order for ordinal levels.}
}
\value{An object of class \code{mergecalib_spec}.}
\description{Defines column mappings and ordered demographic dimensions.}
\examples{
merge_spec(level_orders = list(age = c("young", "old")))
}
